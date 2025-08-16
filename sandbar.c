#include "include/sandbar.h"

#define DIE(fmt, ...)						\
	do {							\
		fprintf(stderr, fmt "\n", ##__VA_ARGS__);	\
		exit(1);					\
	} while (0)
#define EDIE(fmt, ...)						\
	DIE(fmt ": %s", ##__VA_ARGS__, strerror(errno));

#define MIN(a, b)				\
	((a) < (b) ? (a) : (b))
#define MAX(a, b)				\
	((a) > (b) ? (a) : (b))

#define PROGRAM "sandbar"
#define VERSION "0.2"
#define USAGE								\
	"usage: sandbar [OPTIONS]\n"					\
	"Bar Config\n"							\
	"	-hidden					bars will initially be hidden\n" \
	"	-bottom					bars will initially be drawn at the bottom\n" \
	"	-hide-vacant-tags			do not display empty and inactive tags\n" \
	"	-no-title				do not display current view title\n" \
	"	-no-status-commands			disable in-line commands in status text\n" \
	"	-no-layout				do not display the current layout\n" \
	"	-no-mode				do not display the current mode\n" \
	"	-hide-normal-mode			only display the current mode when it is not set to normal\n" \
	"	-font [FONT]				specify a font\n" \
	"	-tags [NUMBER OF TAGS] [FIRST]...[LAST]	specify custom tag names\n" \
	"	-vertical-padding [PIXELS]		specify vertical pixel padding above and below text\n" \
	"	-scale [BUFFER_SCALE]			specify buffer scale value for integer scaling\n" \
	"	-active-fg-color [RGBA]			specify text color of active tags or monitors\n" \
	"	-active-bg-color [RGBA]			specify background color of active tags or monitors\n" \
	"	-inactive-fg-color [RGBA]		specify text color of inactive tags or monitors\n" \
	"	-inactive-bg-color [RGBA]		specify background color of inactive tags or monitors\n" \
	"	-urgent-fg-color [RGBA]			specify text color of urgent tags\n" \
	"	-urgent-bg-color [RGBA]			specify background color of urgent tags\n" \
	"	-title-fg-color [RGBA]			specify text color of title bar\n" \
	"	-title-bg-color [RGBA]			specify background color of title bar\n" \
	"Other\n"							\
	"	-v					get version information\n" \
	"	-h					view this help text\n"

extern
void hide_bar(Bar *bar);

extern
void setup_bar(Bar *bar);

extern
void setup_seat(Seat *seat);

extern
void handle_global(void *data, struct wl_registry *registry,
          uint32_t name, const char *interface, uint32_t version);

extern
void teardown_bar(Bar *bar);

extern
void teardown_seat(Seat *seat);

extern
const struct wl_registry_listener registry_listener;

extern
int read_stdin();

extern
void event_loop();

extern
void sig_handler(int sig);

int
c_main(int argc, char **argv)
{
	Bar *bar, *bar2;
	Seat *seat, *seat2;

	/* Parse options */
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-hide-vacant-tags")) {
			hide_vacant = true;
		} else if (!strcmp(argv[i], "-bottom")) {
			bottom = true;
		} else if (!strcmp(argv[i], "-hidden")) {
			hidden = true;
		} else if (!strcmp(argv[i], "-no-title")) {
			no_title = true;
		} else if (!strcmp(argv[i], "-no-status-commands")) {
			no_status_commands = true;
		} else if (!strcmp(argv[i], "-no-mode")) {
			no_mode = true;
		} else if (!strcmp(argv[i], "-no-layout")) {
			no_layout = true;
		} else if (!strcmp(argv[i], "-hide-normal-mode")) {
			hide_normal_mode = true;
		} else if (!strcmp(argv[i], "-font")) {
			if (++i >= argc)
				DIE("Option -font requires an argument");
			fontstr = argv[i];
		} else if (!strcmp(argv[i], "-vertical-padding")) {
			if (++i >= argc)
				DIE("Option -vertical-padding requires an argument");
			vertical_padding = MAX(MIN(atoi(argv[i]), 100), 0);
		} else if (!strcmp(argv[i], "-scale")) {
			if (++i >= argc)
				DIE("Option -scale requires an argument");
			buffer_scale = strtoul(argv[i], &argv[i] + strlen(argv[i]), 10);
		} else if (!strcmp(argv[i], "-active-fg-color")) {
			if (++i >= argc)
				DIE("Option -active-fg-color requires an argument");
			if (parse_color(argv[i], &active_fg_color) == -1)
				DIE("malformed color string");
		} else if (!strcmp(argv[i], "-active-bg-color")) {
			if (++i >= argc)
				DIE("Option -active-bg-color requires an argument");
			if (parse_color(argv[i], &active_bg_color) == -1)
				DIE("malformed color string");
		} else if (!strcmp(argv[i], "-inactive-fg-color")) {
			if (++i >= argc)
				DIE("Option -inactive-fg-color requires an argument");
			if (parse_color(argv[i], &inactive_fg_color) == -1)
				DIE("malformed color string");
		} else if (!strcmp(argv[i], "-inactive-bg-color")) {
			if (++i >= argc)
				DIE("Option -inactive-bg-color requires an argument");
			if (parse_color(argv[i], &inactive_bg_color) == -1)
				DIE("malformed color string");
		} else if (!strcmp(argv[i], "-urgent-fg-color")) {
			if (++i >= argc)
				DIE("Option -urgent-fg-color requires an argument");
			if (parse_color(argv[i], &urgent_fg_color) == -1)
				DIE("malformed color string");
		} else if (!strcmp(argv[i], "-urgent-bg-color")) {
			if (++i >= argc)
				DIE("Option -urgent-bg-color requires an argument");
			if (parse_color(argv[i], &urgent_bg_color) == -1)
				DIE("malformed color string");
		} else if (!strcmp(argv[i], "-title-fg-color")) {
			if (++i >= argc)
				DIE("Option -title-fg-color requires an argument");
			if (parse_color(argv[i], &title_fg_color) == -1)
				DIE("malformed color string");
		} else if (!strcmp(argv[i], "-title-bg-color")) {
			if (++i >= argc)
				DIE("Option -title-bg-color requires an argument");
			if (parse_color(argv[i], &title_bg_color) == -1)
				DIE("malformed color string");
		} else if (!strcmp(argv[i], "-tags")) {
			if (++i + 1 >= argc)
				DIE("Option -tags requires at least two arguments");
			int v;
			if ((v = atoi(argv[i])) <= 0 || i + v >= argc)
				DIE("-tags: invalid arguments");
			if (tags) {
				for (uint32_t j = 0; j < tags_l; j++)
					free(tags[j]);
				free(tags);
			}
			if (!(tags = malloc(v * sizeof(char *))))
				EDIE("malloc");
			for (int j = 0; j < v; j++)
				if (!(tags[j] = strdup(argv[i + 1 + j])))
					EDIE("strdup");
			tags_l = v;
			i += v;
		} else if (!strcmp(argv[i], "-v")) {
			fprintf(stderr, PROGRAM " " VERSION "\n");
			return 0;
		} else if (!strcmp(argv[i], "-h")) {
			fprintf(stderr, USAGE);
			return 0;
		} else {
			DIE("Option '%s' not recognized\n" USAGE, argv[i]);
		}
	}

	/* Set up display and protocols */
	if (!(display = wl_display_connect(NULL)))
		DIE("Failed to create display");

	wl_list_init(&bar_list);
	wl_list_init(&seat_list);
	
	struct wl_registry *registry = wl_display_get_registry(display);
	wl_registry_add_listener(registry, &registry_listener, NULL);
	wl_display_roundtrip(display);
	if (!compositor || !shm || !layer_shell || !river_status_manager || !river_control)
		DIE("Compositor does not support all needed protocols");

	/* Load selected font */
	fcft_init(FCFT_LOG_COLORIZE_AUTO, 0, FCFT_LOG_CLASS_ERROR);
	fcft_set_scaling_filter(FCFT_SCALING_FILTER_LANCZOS3);

	unsigned int dpi = 96 * buffer_scale;
	char buf[10];
	snprintf(buf, sizeof buf, "dpi=%u", dpi);
	if (!(font = fcft_from_name(1, (const char *[]) {fontstr}, buf)))
		DIE("Could not load font");
	textpadding = font->height / 2;
	height = font->height / buffer_scale + vertical_padding * 2;

	/* Configure tag names */
	if (!tags) {
		tags_l = 9;
		if (!(tags = malloc(tags_l * sizeof(char *))))
			EDIE("malloc");
		char buf[32];
		for (uint32_t i = 0; i < tags_l; i++) {
			snprintf(buf, sizeof(buf), "%d", i + 1);
			if (!(tags[i] = strdup(buf)))
				EDIE("strdup");
		}
	}
	
	/* Setup bars and seats */
	wl_list_for_each(bar, &bar_list, link)
		setup_bar(bar);
	wl_list_for_each(seat, &seat_list, link)
		setup_seat(seat);
	wl_display_roundtrip(display);

	/* Configure stdin */
	if (fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK) == -1)
		EDIE("fcntl");

	/* Set up signals */
	signal(SIGINT, sig_handler);
	signal(SIGHUP, sig_handler);
	signal(SIGTERM, sig_handler);
	signal(SIGCHLD, SIG_IGN);
	
	/* Run */
	run_display = true;
	event_loop();

	/* Clean everything up */
	if (tags) {
		for (uint32_t i = 0; i < tags_l; i++)
			free(tags[i]);
		free(tags);
	}

	wl_list_for_each_safe(bar, bar2, &bar_list, link)
		teardown_bar(bar);
	wl_list_for_each_safe(seat, seat2, &seat_list, link)
		teardown_seat(seat);
	
	zriver_control_v1_destroy(river_control);
	zriver_status_manager_v1_destroy(river_status_manager);
	zwlr_layer_shell_v1_destroy(layer_shell);
	
	fcft_destroy(font);
	fcft_fini();
	
	wl_shm_destroy(shm);
	wl_compositor_destroy(compositor);
	wl_registry_destroy(registry);
	wl_display_disconnect(display);

	return 0;
}

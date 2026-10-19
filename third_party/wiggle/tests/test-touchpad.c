/* Exercise the shipped contact filter and detector without injecting gestures. */
#define main wiggle_monitor_program_main
#include "../scripts/wiggle-monitor.c"
#undef main
#include <assert.h>

static DeviceState pad(int resolution) {
    DeviceState state = {0};
    state.dev = libevdev_new();
    assert(state.dev);
    assert(libevdev_enable_property(state.dev, INPUT_PROP_POINTER) == 0);
    const unsigned int keys[] = {BTN_TOUCH, BTN_TOOL_FINGER, BTN_TOOL_DOUBLETAP,
        BTN_TOOL_TRIPLETAP, BTN_TOOL_QUADTAP, BTN_TOOL_QUINTTAP};
    for (unsigned int i = 0; i < sizeof(keys)/sizeof(keys[0]); ++i)
        assert(libevdev_enable_event_code(state.dev, EV_KEY, keys[i], NULL) == 0);
    struct input_absinfo axis = {.minimum=0, .maximum=4000, .resolution=resolution};
    assert(libevdev_enable_event_code(state.dev, EV_ABS, ABS_X, &axis) == 0);
    assert(libevdev_enable_event_code(state.dev, EV_ABS, ABS_Y, &axis) == 0);
    struct input_absinfo slots = {.minimum=0, .maximum=4};
    assert(libevdev_enable_event_code(state.dev, EV_ABS, ABS_MT_SLOT, &slots) == 0);
    struct input_absinfo ids = {.minimum=0, .maximum=65535, .value=-1};
    assert(libevdev_enable_event_code(state.dev, EV_ABS, ABS_MT_TRACKING_ID, &ids) == 0);
    for (int i=0; i<5; ++i) libevdev_set_slot_value(state.dev, i, ABS_MT_TRACKING_ID, -1);
    assert(device_is_touchpad(state.dev));
    state.touchpad = true;
    state.scale_x = touchpad_scale(state.dev, ABS_X);
    state.scale_y = touchpad_scale(state.dev, ABS_Y);
    reset_contact(&state);
    return state;
}

static bool sample(DeviceState *state, int fingers, int x, int id, int64_t time) {
    libevdev_set_event_value(state->dev, EV_KEY, BTN_TOUCH, fingers>0);
    const unsigned int tools[] = {BTN_TOOL_FINGER, BTN_TOOL_DOUBLETAP,
        BTN_TOOL_TRIPLETAP, BTN_TOOL_QUADTAP, BTN_TOOL_QUINTTAP};
    for (int i=0; i<5; ++i) {
        libevdev_set_event_value(state->dev, EV_KEY, tools[i], fingers==i+1);
        libevdev_set_slot_value(state->dev, i, ABS_MT_TRACKING_ID, i<fingers?id+i:-1);
    }
    libevdev_set_event_value(state->dev, EV_ABS, ABS_X, x);
    libevdev_set_event_value(state->dev, EV_ABS, ABS_Y, 1000);
    double dx, dy;
    return frame_motion(state, &dx, &dy) && detector_update(&state->detector, dx, dy, time);
}

int main(void) {
    DeviceState state = pad(40);
    int triggers=0;
    for (int i=0; i<40; ++i) triggers += sample(&state, 1, i%2?1400:1000, 10, i*20);
    assert(triggers>0);
    puts("PASS: one-finger touchpad shakes trigger the real detector");
    for (int fingers=2; fingers<=5; ++fingers) {
        triggers=0;
        for (int i=0; i<40; ++i) triggers += sample(&state, fingers, i%2?1400:1000, 10, 1000+i*20);
        assert(triggers==0 && !state.position_valid && state.detector.count==0);
    }
    puts("PASS: two-, three-, four-, and five-finger movement is ignored");
    assert(!sample(&state, 1, 3000, 10, 2000));
    for (int i=0; i<30; ++i) assert(!sample(&state, 1, 3000-i*20, 10, 2020+i*20));
    puts("PASS: returning from gestures and straight navigation do not trigger");
    assert(!sample(&state, 0, 1000, 10, 3000));
    assert(!sample(&state, 1, 3000, 20, 3020));
    assert(!sample(&state, 1, 1000, 21, 3040));
    puts("PASS: finger lifts and replaced tracking IDs cannot create jumps");
    libevdev_enable_property(state.dev, INPUT_PROP_DIRECT);
    assert(!device_is_touchpad(state.dev));
    puts("PASS: direct touchscreens stay excluded");
    libevdev_free(state.dev);
    state=pad(0);
    triggers=0;
    for (int i=0; i<40; ++i) triggers += sample(&state, 1, i%2?1400:1000, 10, i*20);
    assert(triggers>0);
    puts("PASS: pads without axis resolution use a working normalized range");
    libevdev_free(state.dev);
    return 0;
}

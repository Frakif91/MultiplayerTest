## Creates a Promise using [constant create_promise(signals : [Array][[Signal]], time_out : float)],
## returns -1 if timed out
class_name Promise extends Node

signal _test_signal

func _init() -> void:
    pass

static func _static_init() -> void:
    pass

## Creates a Promise that return the signal index if one of the signals is emitted before the time_out 
## | returns -1 if timed out
func create_promise(signals_array : Array[Signal], time_out : float) -> int:
    var timer : Timer = Timer.new()
    var signals_checkup : Dictionary[Signal,bool] = {}
    var timed_out = false
    var returned_index = -1
    timer.timeout.connect(func(): timed_out.set(true))
    timer.one_shot = true
    for s in signals_array:
        signals_checkup[s] = false
        s.connect((func(si): signals_checkup[si] = true))
    while signals_array.all(func(s): return not signals_checkup[s]) or not time_out:
        await get_tree().process_frame

    for si in signals_array:
        if signals_checkup[si]:
            returned_index = signals_array.find(si)
    if timed_out:
        returned_index = -1
    return returned_index

func test() -> bool:
    var test_success = true

    # First Test (Signal Test)
    print("-".repeat(20),"\n","Promise Test (Signal Test)")
    get_tree().create_timer(0.5).timeout.connect(func(): _test_signal.emit())
    
    var start_time = Time.get_ticks_msec()
    var p = await self.create_promise([_test_signal],1)
    print("Time taken : ",str(Time.get_ticks_msec()-start_time).pad_decimals(2))
    if not (p == 0):
        push_error("The Promise should have returned 0, returned : " + str(p) + " instead")
        test_success = false
    
    # Second Test (Timeout Test)
    print("-".repeat(20),"\n","Promise Test (Timeout Test)")
    get_tree().create_timer(0.5).timeout.connect(func(): _test_signal.emit())
    start_time = Time.get_ticks_msec()
    p = await self.create_promise([_test_signal],0.1)
    print("Time taken : ",str(Time.get_ticks_msec()-start_time).pad_decimals(2))
    if not (p == -1):
        push_error("The Promise should have returned -1, returned : " + str(p) + " instead")
        test_success = false
    return test_success

    
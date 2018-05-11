
#define DEBUG_MODE_FULL
#include "script_component.hpp"

params ["_unit", "_stateName"];

// If the unit died the loop is finished
if (!alive _unit) exitWith {};

// If locality changed, broadcast the last medical state and finish the local loop
if (!local _unit) exitWith {
    _unit setVariable [VAR_HEART_RATE, GET_HEART_RATE(_unit), true];
    _unit setVariable [VAR_BLOOD_PRESS, _unit getVariable [VAR_BLOOD_PRESS, [80, 120]], true];
    _unit setVariable [VAR_BLOOD_VOL, GET_BLOOD_VOLUME(_unit), true];
};

[_unit] call EFUNC(medical_vitals,handleUnitVitals);

private _painLevel = GET_PAIN_PERCEIVED(_unit);
if (_painLevel > 0) then {
    [_unit, "moan", PAIN_TO_MOAN(_painLevel)] call EFUNC(medical_engine,playInjuredSound);
};

// Handle spontaneous wakeup from unconsciousness
if (EGVAR(medical,spontaneousWakeUpChance) > 0) then {
    if (_unit call EFUNC(medical_status,hasStableVitals)) then {
        private _lastWakeUpCheck = _unit getVariable [QGVAR(lastWakeUpCheck), CBA_missionTime];
        if (CBA_missionTime - _lastWakeUpCheck > SPONTANEOUS_WAKE_UP_INTERVAL) then {
            TRACE_2("Checking for wake up",_unit,EGVAR(medical,spontaneousWakeUpChance));
            _unit setVariable [QGVAR(lastWakeUpCheck), CBA_missionTime];
            if ((random 1) < EGVAR(medical,spontaneousWakeUpChance)) then {
                TRACE_1("Spontaneous wake up!",_unit);
                [QGVAR(WakeUp), _unit] call CBA_fnc_localEvent;
            };
        };
    } else {
        // Unstable vitals, procrastinate the next wakeup check
        _unit setVariable [QGVAR(lastWakeUpCheck), CBA_missionTime];
    };
};
/*
 * Author: Glowbal
 * Handles the medication given to a patient.
 *
 * Arguments:
 * 0: The patient <OBJECT>
 * 1: Treatment class name <STRING>
 * 2: Injection Site Part Number <NUMBER>
 *
 * Return Value:
 * Succesful treatment started <BOOL>
 *
 * Public: Yes
 */
#include "script_component.hpp"

params ["_target", "_className", "_partIndex"];
TRACE_3("params",_target,_className,_partIndex);

if (!EGVAR(medical,advancedMedication)) exitWith {
    if (_className == "Morphine") exitWith {
        #define MORPHINE_PAIN_SUPPRESSION 0.6
        private _painSupress = GET_PAIN_SUPPRESS(_target);
        _target setVariable [VAR_PAIN_SUPP, (_painSupress + MORPHINE_PAIN_SUPPRESSION) min 1, true];
    };

    if (_className == "Epinephrine") exitWith {
        [QEGVAR(medical,WakeUp), _target] call CBA_fnc_localEvent;
    };
};

private _tourniquets = _target getVariable [QEGVAR(medical,tourniquets), [0,0,0,0,0,0]];

if (_tourniquets select _partIndex > 0) exitWith {
    TRACE_1("unit has tourniquets blocking blood flow on injection site",_tourniquets);
    private _delayedMedications = _target getVariable [QEGVAR(medical,occludedMedications), []];

    _delayedMedications pushBack _this;
    _target setVariable [QEGVAR(medical,occludedMedications), _delayedMedications, true];

    true
};

// We have added a new dose of this medication to our system, so let's increase it
private _varName = format [QGVAR(%1_inSystem), _className];
private _currentInSystem = _target getVariable [_varName, 0];
_target setVariable [_varName, _currentInSystem + 1];

// Find the proper attributes for the used medication
private _medicationConfig = configFile >> QUOTE(ADDON) >> "Medication";
private _painReduce = getNumber (_medicationConfig >> "painReduce");
private _hrIncreaseLow = getArray (_medicationConfig >> "hrIncreaseLow");
private _hrIncreaseNorm = getArray (_medicationConfig >> "hrIncreaseNormal");
private _hrIncreaseHigh = getArray (_medicationConfig >> "hrIncreaseHigh");
private _timeInSystem = getNumber (_medicationConfig >> "timeInSystem");
private _timeTillMaxEffect = getNumber (_medicationConfig >> "timeTillMaxEffect");
private _maxDose = getNumber (_medicationConfig >> "maxDose");
private _viscosityChange = getNumber (_medicationConfig >> "viscosityChange");

private _inCompatableMedication = [];

if (isClass (_medicationConfig >> _className)) then {
    _medicationConfig = _medicationConfig >> _className;
    if (isNumber (_medicationConfig >> "painReduce")) then { _painReduce = getNumber (_medicationConfig >> "painReduce");};
    if (isArray (_medicationConfig >> "hrIncreaseLow")) then { _hrIncreaseLow = getArray (_medicationConfig >> "hrIncreaseLow"); };
    if (isArray (_medicationConfig >> "hrIncreaseNormal")) then { _hrIncreaseNorm = getArray (_medicationConfig >> "hrIncreaseNormal"); };
    if (isArray (_medicationConfig >> "hrIncreaseHigh")) then { _hrIncreaseHigh = getArray (_medicationConfig >> "hrIncreaseHigh"); };
    if (isNumber (_medicationConfig >> "timeInSystem")) then { _timeInSystem = getNumber (_medicationConfig >> "timeInSystem"); };
    if (isNumber (_medicationConfig >> "timeTillMaxEffect")) then { _timeTillMaxEffect = getNumber (_medicationConfig >> "timeTillMaxEffect"); };
    if (isNumber (_medicationConfig >> "maxDose")) then { _maxDose = getNumber (_medicationConfig >> "maxDose"); };
    if (isArray (_medicationConfig >> "inCompatableMedication")) then { _inCompatableMedication = getArray (_medicationConfig >> "inCompatableMedication"); };
    if (isNumber (_medicationConfig >> "viscosityChange")) then { _viscosityChange = getNumber (_medicationConfig >> "viscosityChange"); };
};

if (alive _target) then {
    private _heartRate = GET_HEART_RATE(_target);
    private _hrIncrease = [_hrIncreaseLow, _hrIncreaseNorm, _hrIncreaseHigh] select (floor ((0 max _heartRate min 110) / 55));
    _hrIncrease params ["_minIncrease", "_maxIncrease"];
    private _heartRateChange = _minIncrease + random (_maxIncrease - _minIncrease);

    // Adjust the heart rate based upon config entry
    if (_heartRateChange != 0) then {
        private _heartRateAdjustments = GETVAR(_target,VAR_HEART_RATE_ADJ,[]);
        _heartRateAdjustments pushBack [_heartRateChange, _timeTillMaxEffect, _timeInSystem, 0];
        _target setVariable [VAR_HEART_RATE_ADJ, _heartRateAdjustments];
    };

    // Adjust the pain suppression based upon config entry
    if (_painReduce > 0) then {
        private _adjustments = _target getVariable [VAR_PAIN_SUPP_ADJ, []];
        _adjustments pushBack [_painReduce, _timeTillMaxEffect, _timeInSystem, 0];
        _target setVariable [VAR_PAIN_SUPP_ADJ, _adjustments];
    };

    // Adjust the peripheral resistance based upon config entry
    if (_viscosityChange != 0) then {
        private _peripheralResistanceAdjustments = _target getVariable [QEGVAR(medical,peripheralResistanceAdjustments), []];
        _peripheralResistanceAdjustments pushBack [_viscosityChange, _timeTillMaxEffect, _timeInSystem, 0];
        _target setVariable [QEGVAR(medical,peripheralResistanceAdjustments), _peripheralResistanceAdjustments];
    };
};

true
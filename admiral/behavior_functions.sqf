#include "admiral_defines.h"

adm_behavior_fnc_changeAllGroupState = {
    waitUntil {
        {
            [_x] call (adm_behavior_states select (_x getVariable ["adm_behavior_state", STATE_INIT]));
        } foreach ([] call adm_behavior_fnc_getAllGroups);
        sleep 1;
        false;
    };
};

adm_behavior_fnc_stateInit = {
    FUN_ARGS_1(_group);

    _group setVariable ["adm_behavior_state", STATE_MOVING, false];
    if (adm_ai_debugging) then {
        player groupChat LOG_MSG_1("DEBUG","Behavior - Group '%1' initialized.", _group);
        diag_log LOG_MSG_1("DEBUG","Behavior - Group '%1' initialized.", _group);
    };
};

adm_behavior_fnc_stateMoving = {
    FUN_ARGS_1(_group);

    private ["_nextState", "_enemy"];
    _nextState = STATE_MOVING;
    _enemy = (leader _group) findNearestEnemy (leader _group);
    if (!isNull _enemy && {!((vehicle _enemy) isKindOf "Air")}) then {
        _nextState = STATE_ENEMYFOUND;
        _group setVariable ["adm_behavior_enemyPos", getPosATL _enemy, false];
        if (adm_ai_debugging) then {
            player groupChat LOG_MSG_2("DEBUG","Behavior - Group '%1' found enemy '%2'!", _group, _enemy);
            diag_log LOG_MSG_2("DEBUG","Behavior - Group '%1' found enemy '%2'!", _group, _enemy);
        };
    };
    _group setVariable ["adm_behavior_state", _nextState, false];
};

adm_behavior_fnc_stateEnemyFound = {
    FUN_ARGS_1(_group);

    private "_enemyPos";
    _enemyPos = _group getVariable "adm_behavior_enemyPos";
    if ([_enemyPos] call adm_behavior_fnc_canCallReinforcement) then {
        [_group, _enemyPos, [_enemyPos] call adm_behavior_fnc_getEnemyNumbers] call adm_behavior_fnc_callReinforcement;
        PUSH(adm_behavior_foundEnemies, AS_ARRAY_2(time,_enemyPos));
    };
    _group setVariable ["adm_behavior_state", STATE_SADENEMY, false];
};

adm_behavior_fnc_stateSeekAndDestroyEnemy = {
    FUN_ARGS_1(_group);

    private "_sadWp";
    _sadWp = [_group, [_group getVariable "adm_behavior_enemyPos", 0], 'SAD', 'AWARE', 'RED'] call adm_common_fnc_createWaypoint;
    _sadWp setWaypointStatements ["true", "[group this] call adm_behavior_fnc_continueMoving;"];
    _group setVariable ["adm_behavior_lastWp", currentWaypoint _group, false];
    _group setVariable ["adm_behavior_state", STATE_COMBAT, false];
    _group setCurrentWaypoint _sadWp;
    if (adm_ai_debugging) then {
        player groupChat LOG_MSG_1("DEBUG","Behavior - Group '%1' moves to SAD waypoint.", _group);
        diag_log LOG_MSG_1("DEBUG","Behavior - Group '%1' moves to SAD waypoint.", _group);
    };
};

adm_behavior_fnc_stateCombat = {
    FUN_ARGS_1(_group);

    private "_reinfGroup";
    _reinfGroup = _group getVariable "adm_behavior_reinfGroup";
    if (!isNil {_reinfGroup}) then {
        private "_enemyPos";
        _enemyPos = _group getVariable "adm_behavior_enemyPos";
        if (!alive leader _reinfGroup) then {
            if (adm_ai_debugging) then {
                player groupChat LOG_MSG_2("DEBUG","Behavior - Group '%1' tries to call additinal reinforcement, becasue reinforced group '%2' died.", _group, _reinfGroup);
                diag_log LOG_MSG_2("DEBUG","Behavior - Group '%1' tries to call additinal reinforcement, becasue reinforced group '%2' died.", _group, _reinfGroup);
            };
            private "_enemyNumbers";
            _enemyNumbers = [_enemyPos] call adm_behavior_fnc_getEnemyNumbers;
            _group setVariable ["adm_behavior_reinfGroup", nil];
            [_group, _enemyPos, [ceil random (_enemyNumbers select 0), floor random (_enemyNumbers select 1), floor random (_enemyNumbers select 2)]] call adm_behavior_fnc_callReinforcement;
        } else {
            if (_reinfGroup getVariable "adm_behavior_state" == STATE_MOVING && {leader _group distance _enemyPos > BEHAVIOR_REINF_TURNAROUND_DIST}) then {
                [_group] call adm_behavior_fnc_continueMoving;
                if (adm_ai_debugging) then {
                    player groupChat LOG_MSG_2("DEBUG","Behavior - Group '%1' returns patrolling, becasue reinforced group '%2' is not in combat.", _group, _reinfGroup);
                    diag_log LOG_MSG_2("DEBUG","Behavior - Group '%1' returns patrolling, becasue reinforced group '%2' is not in combat.", _group, _reinfGroup);
                };
            };
        };
    };
};

adm_behavior_fnc_continueMoving = {
    FUN_ARGS_1(_group);

    _group setCurrentWaypoint [_group, _group getVariable "adm_behavior_lastWp"];
    _group setVariable ["adm_behavior_state", STATE_MOVING, false];
    _group setVariable ["adm_behavior_enemyPos", nil, false];
    _group setVariable ["adm_behavior_reinfGroup", nil, false];
    deleteWaypoint [_group, (count waypoints _group) - 1];
    if (adm_ai_debugging) then {
        player groupChat LOG_MSG_1("DEBUG","Behavior - Group '%1' returns patrolling.", _group);
        diag_log LOG_MSG_1("DEBUG","Behavior - Group '%1' returns patrolling.", _group);
    };
};

adm_behavior_fnc_getEnemyNumbers = {
    FUN_ARGS_1(_enemyPos);

    private "_enemyNumbers";
    _enemyNumbers = [1, 0, 0];
    {
        if (_x distance _enemyPos <= BEHAVIOR_ENEMY_CHECK_RADIUS && {alive _x}) then {
            _enemyNumbers set [0, (_enemyNumbers select 0) + 1];
            if (vehicle _x != _x) then {
                call {
                    if ((vehicle _x) isKindOf "Car") exitWith {_enemyNumbers set [1, (_enemyNumbers select 1) + 1];};
                    if ((vehicle _x) isKindOf "Air") exitWith {_enemyNumbers set [2, (_enemyNumbers select 2) + 1];};
                };
            };
        };
    } foreach playableUnits;

    _enemyNumbers;
};

adm_behavior_fnc_canCallReinforcement = {
    FUN_ARGS_1(_enemyPos);

    private "_canCall";
    _canCall = true;
    {
        if ((_x select 0) + BEHAVIOR_REINF_COOLDOWN > time || {(_x select 1) distance _enemyPos < BEHAVIOR_ENEMY_CHECK_RADIUS}) exitWith {
            _canCall = false;
        };
    } foreach adm_behavior_foundEnemies;

    _canCall || {floor random 100 < BEHAVIOR_CANCALL_PERCENT_CHANCE};
};

adm_behavior_fnc_callReinforcement = {
    FUN_ARGS_3(_group,_enemyPos,_enemyNumbers);

    if (adm_ai_debugging) then {
        private "_callNumbers";
        _callNumbers = [BEHAVIOR_REINF_NUM(_enemyNumbers,1,1,1) + 1, BEHAVIOR_REINF_NUM(_enemyNumbers,3,1,1), BEHAVIOR_REINF_NUM(_enemyNumbers,4,2,1)];
        player groupChat LOG_MSG_4("DEBUG","Behavior - Group '%1' found %2 number of enemies and tries to call %3 number of reinforcements at position %4.", _group, _enemyNumbers, _callNumbers, _enemyPos);
        diag_log LOG_MSG_4("DEBUG","Behavior - Group '%1' found %2 number of enemies and tries to call %3 number of reinforcements at position %4.", _group, _enemyNumbers, _callNumbers, _enemyPos);
    };
    [_group, _enemyPos, BEHAVIOR_REINF_NUM(_enemyNumbers,1,1,1) + 1, adm_behavior_fnc_getAvailableInfGroups] call adm_behavior_fnc_callReinforcementGroups;
    [_group, _enemyPos, BEHAVIOR_REINF_NUM(_enemyNumbers,3,1,1), adm_behavior_fnc_getAvailableTechGroups] call adm_behavior_fnc_callReinforcementGroups;
    [_group, _enemyPos, BEHAVIOR_REINF_NUM(_enemyNumbers,4,2,1), adm_behavior_fnc_getAvailableArmourGroups] call adm_behavior_fnc_callReinforcementGroups;
};

adm_behavior_fnc_callReinforcementGroups = {
    FUN_ARGS_4(_group,_enemyPos,_count,_groupFunc);

    private "_groups";
    _groups = [_enemyPos, _count, [_enemyPos] call _groupFunc] call adm_behavior_fnc_getReinforcementGroups;
    {
        if ([_x] call adm_behavior_fnc_canReinforce) then {
            _x setVariable ["adm_behavior_enemyPos", _enemyPos, false];
            _x setVariable ["adm_behavior_reinfGroup", _group, false];
            _x setVariable ["adm_behavior_state", STATE_SADENEMY, false];
        };
    } foreach _groups;
};

adm_behavior_fnc_getReinforcementGroups = {
    FUN_ARGS_3(_enemyPos,_numberOfGroups,_groups);

    private "_reinforcementGroups";
    _reinforcementGroups = [];
    if (_numberOfGroups > 0) then {
        private "_closestGroups";
        _closestGroups = [_groups, {leader _x distance _enemyPos > leader _y distance _enemyPos}] call adm_common_fnc_insertionSort;
        for "_i" from 0 to (_numberOfGroups min (count _closestGroups)) - 1 do {
            PUSH(_reinforcementGroups, _closestGroups select _i);
        };
    };

    _reinforcementGroups;
};

adm_behavior_fnc_canReinforce = {
    FUN_ARGS_1(_group);

    _group getVariable ["adm_behavior_state", STATE_INIT] == STATE_MOVING;
};

adm_behavior_fnc_getAllGroups = {
    private ["_groups"];
    _groups = [];
    FILTER_PUSH_ALL(_groups, adm_patrol_infGroups, {alive leader _x});
    FILTER_PUSH_ALL(_groups, adm_patrol_techGroups, {alive leader _x});
    FILTER_PUSH_ALL(_groups, adm_patrol_armourGroups, {alive leader _x});
    FILTER_PUSH_ALL(_groups, adm_camp_infGroups, {alive leader _x});
    FILTER_PUSH_ALL(_groups, adm_camp_techGroups, {alive leader _x});
    FILTER_PUSH_ALL(_groups, adm_camp_armourGroups, {alive leader _x});
    _groups;
};

adm_behavior_fnc_getAvailableInfGroups = {
    FUN_ARGS_1(_enemyPos);

    private ["_groups"];
    _groups = [];
    FILTER_PUSH_ALL(_groups, adm_patrol_infGroups, {alive leader _x && {leader _x distance _enemyPos <= BEHAVIOR_MAX_REINFORCEMENT_DIST} && {[_x] call adm_behavior_fnc_canReinforce}});
    FILTER_PUSH_ALL(_groups, adm_camp_infGroups, {alive leader _x && {leader _x distance _enemyPos <= BEHAVIOR_MAX_REINFORCEMENT_DIST} && {[_x] call adm_behavior_fnc_canReinforce}});
    _groups;
};

adm_behavior_fnc_getAvailableTechGroups = {
    FUN_ARGS_1(_enemyPos);

    private ["_groups"];
    _groups = [];
    FILTER_PUSH_ALL(_groups, adm_patrol_techGroups, {alive leader _x && {leader _x distance _enemyPos <= BEHAVIOR_MAX_REINFORCEMENT_DIST} && {[_x] call adm_behavior_fnc_canReinforce}});
    FILTER_PUSH_ALL(_groups, adm_camp_techGroups, {alive leader _x && {leader _x distance _enemyPos <= BEHAVIOR_MAX_REINFORCEMENT_DIST} && {[_x] call adm_behavior_fnc_canReinforce}});
    _groups;
};

adm_behavior_fnc_getAvailableArmourGroups = {
    FUN_ARGS_1(_enemyPos);

    private ["_groups"];
    _groups = [];
    FILTER_PUSH_ALL(_groups, adm_patrol_armourGroups, {alive leader _x && {leader _x distance _enemyPos <= BEHAVIOR_MAX_REINFORCEMENT_DIST} && {[_x] call adm_behavior_fnc_canReinforce}});
    FILTER_PUSH_ALL(_groups, adm_camp_armourGroups, {alive leader _x && {leader _x distance _enemyPos <= BEHAVIOR_MAX_REINFORCEMENT_DIST} && {[_x] call adm_behavior_fnc_canReinforce}});
    _groups;
};


adm_behavior_fnc_init = {
    adm_behavior_states = [adm_behavior_fnc_stateInit, adm_behavior_fnc_stateMoving, adm_behavior_fnc_stateEnemyFound, adm_behavior_fnc_stateSeekAndDestroyEnemy, adm_behavior_fnc_stateCombat, {}];
    adm_behavior_foundEnemies = [];
    [] spawn adm_behavior_fnc_changeAllGroupState;
};
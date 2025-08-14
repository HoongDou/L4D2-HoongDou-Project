#pragma semicolon 1 
#pragma newdecls required 

#include <left4dhooks>
#include <l4d2_saferoom_detect>

ConVar gameMode;

int aliveClient = -1;

public Plugin myinfo = {
    name = "Versus To Coop Switcher",
    author = "HoongDou",
    description = "Switches gamemode from versus to coop under certain conditions.",
    version = "1.3", 
    url = "None"
};

public void OnPluginStart()
{
    gameMode = FindConVar("mp_gamemode");
    if (gameMode == null)
    {
        LogError("Failed to find ConVar 'mp_gamemode'. Plugin will not function correctly.");
        return;
    }

    HookEvent("door_close", Event_DoorClose, EventHookMode_Pre);
    HookEvent("player_incapacitated", Event_PlayerIncap, EventHookMode_Post);
    HookEvent("mission_lost", Event_MissionLost, EventHookMode_Post);
    HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
}
// 地图开始时的处理
public void OnMapStart()
{
    CreateTimer(1.0, Timer_MapStartCheck, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_MapStartCheck(Handle timer)
{
    // 确保地图开始时总是versus模式
    if (gameMode != null)
    {
        char currentMode[32];
        gameMode.GetString(currentMode, sizeof(currentMode));
        
        if (!StrEqual(currentMode, "versus", false))
        {
            gameMode.SetString("versus");
            PrintToServer("[VersusToCoop] Map started, forcing gamemode to VERSUS.");
        }
    }
    return Plugin_Continue;
}
public Action Event_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
    // 此事件在玩家倒下时触发，主要是用于即时检查整个团队是否都处于无救状态。

    if (IsTeamImmobilised())
    {
        SetCoop();
        
    }
    return Plugin_Continue;
}

// 安全门关闭触发
public Action Event_DoorClose(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    bool checkpoint = event.GetBool("checkpoint");
    if (checkpoint && client > 0 && IsValidClient(client))
    {
        aliveClient = client;
    }
    return Plugin_Continue;
}

// versus回合结束时调用
public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    if (aliveClient > 0 && SAFEDETECT_IsPlayerInEndSaferoom(aliveClient))
    {
        if (gameMode != null) {
            gameMode.SetString("coop");
            PrintToServer("[VersusToCoop] Player in end saferoom, switching to COOP for next map.");
        }
    }
    else
    {
        SetCoop(); // 确保玩家不在安全区且没有记录的aliveClient，会切换到coop。
    }
    aliveClient = -1;
    return Plugin_Handled;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (gameMode != null)
    {
        char currentMode[32];
        gameMode.GetString(currentMode, sizeof(currentMode));
        if (StrEqual(currentMode, "coop", false)) 
        {
            gameMode.SetString("versus");
            PrintToServer("[VersusToCoop] Round start, switching gamemode to VERSUS.");
        }
        // 注：目前只针对coop会切换到versus，其他模式(e.g.生还者模式)是不进行操作的。
    }
    return Plugin_Continue;
}

public Action Event_MissionLost(Event event, const char[] name, bool dontBroadcast)
{
    SetCoop();
    return Plugin_Continue;
}

public void SetCoop()
{
    if (gameMode != null)
    {
        CreateTimer(0.1, Timer_SetCoop_Internal, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

// coop的回调函数
public Action Timer_SetCoop_Internal(Handle timer)
{
    if (gameMode != null)
    {
        char currentMode[32];
        gameMode.GetString(currentMode, sizeof(currentMode));
        if (!StrEqual(currentMode, "coop", false)) { // Check if not already coop
            gameMode.SetString("coop");
            PrintToServer("[VersusToCoop] Gamemode switched to COOP.");
        }
    }
    return Plugin_Handled;
}


/** 此函数在原始逻辑中的 SetVersusTimer 是用于旧版本中要给0.1s的计时器回调，目前无需使用。
 * public Action SetVersusTimer(Handle timer)
 * {
 *     if (gameMode != null)
 *     {
 *         gameMode.SetString("versus");
 *     }
 *     return Plugin_Handled;
 * }
*/

/**
 * 检查整个幸存者队伍是否处于团灭状态。
 * 一个队伍被认为团灭，条件是：
 * 1. 至少有一名幸存者玩家。
 * 2. 所有当前仍然存活的幸存者玩家都处于倒地状态。
 */
bool IsTeamImmobilised()
{
    bool atLeastOneSurvivorAlive = false;
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsSurvivor(client) && IsPlayerAlive(client)) // 标记幸存者Alive
        {
            atLeastOneSurvivorAlive = true;
            if (!IsIncapacitated(client))
            {
                // 如果找到任何一个活着的幸存者没有倒地，则队伍没有处于团灭
                return false;
            }
        }
    }
    // 如果循环完成：
    // - 并且 atLeastOneSurvivorAlive 为 true：所有检查到的活着的幸存者确实都倒地了。
    // - 并且 atLeastOneSurvivorAlive 为 false：没有找到活着的幸存者 (都死了或游戏未开始)。
    // 只有当至少有一名活着的幸存者，并且他们全部倒地时，队伍才算作为团灭状态。
    return atLeastOneSurvivorAlive;
}

/**
 * 检查指定的客户端是否处于倒地状态。
 * 目标逻辑：将已死亡的玩家也视作倒地状态。
 */
bool IsIncapacitated(int client)
{
    if (!IsValidClient(client) || GetClientTeam(client) != L4D_TEAM_SURVIVOR)
    {
        return false; 
    }

    if (!IsPlayerAlive(client))
    {
        return true;
    }

	// 如果玩家活着，检查 m_isIncapacitated 属性。
    return GetEntProp(client, Prop_Send, "m_isIncapacitated") != 0;
}

bool IsSurvivor(int client)
{
    return IsValidClient(client) && GetClientTeam(client) == L4D_TEAM_SURVIVOR;
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients || !IsClientConnected(client))
    {
        return false;
    }
    return IsClientInGame(client);
}


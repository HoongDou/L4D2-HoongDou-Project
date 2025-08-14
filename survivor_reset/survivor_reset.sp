#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2_saferoom_detect>

#define PLUGIN_VERSION "2.7"

// 全局变量
ConVar g_hSurvivorRespawnHealth;
bool g_bEndDoorClosedThisRound = false;// 用于防止关卡结束时重复治疗
bool g_bMapTransitionOccurred = false; // 换图阶段，防止重生时重置武器
int aliveClient = -1;
public Plugin myinfo =
{
    name = "Survivor Manager (Reset & Heal)",
    description = "在关卡结束时重置生还者血量并给予手枪，在关卡开始时恢复生还者血量为满血。",
    author = "Breezy & HoongDou",
    version = PLUGIN_VERSION,
    url = "https://www.sourcemod.net/"
};

// ===================================================================================
// 插件生命周期函数
// ===================================================================================

public void OnPluginStart()
{
    // 查找并设置 ConVar
    g_hSurvivorRespawnHealth = FindConVar("z_survivor_respawn_health");
    if (g_hSurvivorRespawnHealth == null) {
        SetFailState("无法找到ConVar 'z_survivor_respawn_health'，插件无法加载。");
    }
    SetConVarCheatInt(g_hSurvivorRespawnHealth, 100);
    // 挂载事件和 Forward
    // 关卡开始时，触发完整重置,并在玩家生成时确保血量为100
    HookEvent("round_start", Event_OnRoundStart, EventHookMode_Post);
    HookEvent("door_close", Event_OnDoorClose, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd); 
    HookEvent("map_transition", Event_MapTransition, EventHookMode_Post);
    HookEvent("finale_win", Event_FinaleWin, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
}

public void OnPluginEnd()
{
    if (g_hSurvivorRespawnHealth != null) {
        g_hSurvivorRespawnHealth.RestoreDefault();
    }
}

// ===================================================================================
// 事件和 Forward 回调
// ===================================================================================

/**
 * @brief 地图开始时触发
 */
public void OnMapStart()
{
    g_bEndDoorClosedThisRound = false;
    CreateTimer(3.0, Timer_FullResetOnStart);
}
public void OnClientPutInServer(int client)
{
	if (client && IsClientConnected(client) && g_bMapTransitionOccurred)
		CreateTimer(5.0, Timer_FullResetOnStart);
        g_bMapTransitionOccurred = false;
}
public void OnMapEnd()
{
    g_bMapTransitionOccurred = true; // 标记地图转换
}
/**
 * @brief 关卡开始时触发
 */
public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_bEndDoorClosedThisRound = false;
    CreateTimer(0.1, Timer_FullResetOnStart);
}

/**
 * @brief 关卡结束时触发 (通过关闭门事件)
 */
public void Event_OnDoorClose(Event event, const char[] name, bool dontBroadcast)
{
    if (g_bEndDoorClosedThisRound) return;

    int client = GetClientOfUserId(GetEventInt(event, "userid"));

    // 必须是有效的生还者，关闭了检查点门，并且位于终点安全区
    if (IsClientSurvivor(client) && IsPlayerAlive(client) && GetEventBool(event, "checkpoint") && SAFEDETECT_IsPlayerInEndSaferoom(client)) {
        if (AreAllSurvivorsInEndSaferoom())
        {
            g_bEndDoorClosedThisRound = true;
            CreateTimer(0.1, Timer_FullResetOnEnd);
        }
    }
}

/**
 * @brief 对抗回合结束时触发 
 */
 public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
    if (aliveClient > 0 && SAFEDETECT_IsPlayerInEndSaferoom(aliveClient))
    {
		CreateTimer(0.1, Timer_FullResetOnEnd);
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
   if (aliveClient > 0 && SAFEDETECT_IsPlayerInEndSaferoom(aliveClient))
    {
		CreateTimer(0.1, Timer_FullResetOnEnd);
    }
}

/**
 * @brief 当地图切换时触发所有人回血
 *    这作为一个补充的health check
 */
public void Event_MapTransition(Event event, const char[] name, bool dontBroadcast)
{
    g_bMapTransitionOccurred = true;
	CreateTimer(0.0, Timer_FullResetOnEnd);
}

public void Event_FinaleWin(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.1, Timer_FullResetOnEnd);
}
/**
 * @brief 当玩家生成时重置武器
 *    这作为一个主要的check
 */
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsClientSurvivor(client) && g_bMapTransitionOccurred) 
    {
        CreateTimer(0.5, Timer_FullResetOnStart, client, TIMER_FLAG_NO_MAPCHANGE);
    }
}
/**
 * @brief 当第一个生还者离开起始安全区时触发 (来自 left4dhooks)
 *    这作为一个补充的health check，确保生还者出门时状态良好。
 */
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    // 只执行回血，不重置物品
    HealAllSurvivorsToFull();
    return Plugin_Continue;
}

// ===================================================================================
// 定时器回调
// ===================================================================================

/**
 * @brief 定时器：在关卡结束时执行完整的重置（回血+手枪）
 */
public Action Timer_FullResetOnEnd(Handle timer, any data)
{
    LogMessage("终点安全门已关闭，正在给所有生还者回血...");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientSurvivor(i)) {
            HealSurvivorToFull(i);
            StripInventoryAndGivePistol(i);
        }
    }
    return Plugin_Stop; // Plugin_Stop，定时器执行一次后停止
}
/**
 * @brief 定时器：在地图开始时执行完整的重置（回血+手枪）
 */
public Action Timer_FullResetOnStart(Handle timer, any data)
{
    LogMessage("地图开始，正在给所有生还者回血...");
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientSurvivor(i)) {
            HealSurvivorToFull(i);
            StripInventoryAndGivePistol(i);
        }
    }
    return Plugin_Stop; // Plugin_Stop，定时器执行一次后停止
}
/**
 * @brief 定时器：在关卡开始时执行回血
 */
public Action Timer_HealOnStart(Handle timer, any data)
{
    LogMessage("关卡开始，正在重置所有生还者血量...");
    HealAllSurvivorsToFull();
    return Plugin_Stop; // Plugin_Stop，定时器执行一次后停止
}

// ===================================================================================
// 核心功能函数
// ===================================================================================

/**
 * @brief 给所有存活的生还者恢复到满血。
 */
void HealAllSurvivorsToFull()
{
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientSurvivor(i) && IsPlayerAlive(i)) {
            HealSurvivorToFull(i);
			Give(i, "give","health"); 
        }
    }
}

/**
 * @brief 治疗单个生还者到满血，并重置倒地状态，通过直接设置生命值实现。
 */
void HealSurvivorToFull(int client)
{
    // 直接设置生命值并重置所有相关状态
    int maxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
    if (maxHealth <= 0) maxHealth = 100; // 安全校验

    SetEntProp(client, Prop_Send, "m_iHealth", maxHealth);
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
    SetEntProp(client, Prop_Send, "m_currentReviveCount", 0);
    SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
    SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
}

/**
 * @brief 清空指定玩家的物品栏，并给予一把手枪。
 */
void StripInventoryAndGivePistol(int client)
{
    // 检查玩家状态，避免在特殊动画时移除物品
    if (GetEntProp(client, Prop_Send, "m_isIncapacitated") || 
        GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
        return;

    // 移除所有武器槽位的物品
    for (int slot = 0; slot < 5; slot++) {
        int weapon = GetPlayerWeaponSlot(client, slot);
        if (IsValidEdict(weapon)) {
            RemovePlayerItem(client, weapon);
            AcceptEntityInput(weapon, "Kill"); // 使用Kill作为标准销毁方式
        }
    }
    LogMessage("成功重置生还者物品，正在给予生还者初始武器...");
    // 给予一把新的手枪
    Give(client, "give","weapon_pistol");
    LogMessage("成功给予生还者初始小手枪...");
}

// ===================================================================================
// 辅助函数
// ===================================================================================

/**
 * @brief 检查一个客户端是否是有效的、在游戏中的生还者。
 */
bool IsClientSurvivor(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

/**
 * @brief 检查是否所有存活的生还者都位于终点安全区。
 * @return  如果所有存活的生还者都在终点安全区，则返回true；否则返回false。
 */
bool AreAllSurvivorsInEndSaferoom()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        // 遍历存活的生还者
        if (IsClientSurvivor(i) && IsPlayerAlive(i))
        {
            // 地图名称非空校验
            char map[128];
            GetCurrentMap(map, sizeof(map));
            // 不在终点安全区.
            if (strlen(map) > 0 && !SAFEDETECT_IsPlayerInEndSaferoom(i))
            {
                return false;
            }
        }
    }
    // 如果循环完成，说明所有存活的生还者都到在重点安全区。
    return true;
}

/**
 * @brief 临时修改一个受保护的(cheat)ConVar的整数值。
 */
void SetConVarCheatInt(ConVar cvar, int value)
{
    int originalFlags = cvar.Flags;
    cvar.Flags &= ~FCVAR_CHEAT;
    cvar.SetInt(value, true, false);
    cvar.Flags = originalFlags;
}

/**
 * @brief 给give一个临时修改Cheat ConVar。
 */
void Give(int client, char[] strCommand, char[] strParam1)
{
	int flags = GetCommandFlags(strCommand);
	SetCommandFlags(strCommand, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", strCommand, strParam1);
	SetCommandFlags(strCommand, flags);
}
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <readyup>

// 定义L4D2中生还者团队的索引。
#define L4DTeam_Survivor 2

//================================================================================
// 外部插件函数	|From ReadyUp Natives
//================================================================================

// Native functions from readyup plugin
/**
 * 检查游戏当前是否处于准备阶段。
 * @return      True if in ready-up phase, false otherwise.
 */
native bool IsInReady();

/**
 * 检查特定玩家是否已标记为准备就绪。
 * @param client    The client index.
 * @return          True if the client is ready, false otherwise.
 */
native bool IsReady(int client);

//================================================================================
// 全局变量
//================================================================================

// 追踪自动开始指令是否已被本插件触发，以防止每秒都重复执行 sm_forcestart。
bool g_bAutoStartTriggered = false;
// 在倒计时被取消后充当“锁”。当为 true 时，即使所有人都准备就绪，自动开始的倒计时也不会触发。
// 这个锁只在一个玩家变为“未准备”状态时才会解除。
bool g_bCountdownCancelled = false;
// 用于检查玩家准备状态的主计时器的句柄。
Handle g_hCheckReadyTimer = null;

public Plugin myinfo =
{
    name = "ReadyUp Extension",
    author = "HoongDou",
    description = "Extends the L4D2 Ready-Up plugin with a highly robust auto-start and a universal sm_fs command.",
    version = "1.4",
    url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

public void OnPluginStart()
{
    RegConsoleCmd("sm_fs", Command_ForceStart, "让任何玩家都能强制开始游戏。");
}

public void OnAllPluginsLoaded()
{
	// 确保'readyup'正在运行。
    if (!LibraryExists("readyup"))
    {
        SetFailState("This plugin requires 'readyup.smx'. Please ensure the main ready-up plugin is installed and running.");
    }
}

public void OnMapStart()
{
    g_bAutoStartTriggered = false;
    g_bCountdownCancelled = false;  // 重置取消标志
    if (g_hCheckReadyTimer != null)
    {
        delete g_hCheckReadyTimer;
    }
    g_hCheckReadyTimer = CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
    if (g_hCheckReadyTimer != null)
    {
        delete g_hCheckReadyTimer;
        g_hCheckReadyTimer = null;
    }
}

public Action Timer_CheckReady(Handle timer)
{
    if (!IsInReady() || g_bAutoStartTriggered)
    {
        return Plugin_Continue;
    }

    // 检查是否所有生还者都准备就绪
    bool allReady = true;
    bool hasUnreadyPlayer = false;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == L4DTeam_Survivor && !IsFakeClient(i))
        {
            if (!IsReady(i))
            {
                allReady = false;
                hasUnreadyPlayer = true;
            }
        }
    }

    // 如果有人unready，重置取消标志
    if (hasUnreadyPlayer && g_bCountdownCancelled)
    {
        g_bCountdownCancelled = false;
    }

    // 只有在所有人准备且倒计时未被取消的情况下才触发自动开始
    if (allReady && !g_bCountdownCancelled)
    {
        PrintToChatAll(" \x04[!] \x01所有生还者已准备就绪，开始倒计时！");
        ServerCommand("sm_forcestart");
        g_bAutoStartTriggered = true;
    }

    return Plugin_Continue;
}

public void OnReadyCountdownCancelled(int client, char sDisruptReason)
{
    g_bAutoStartTriggered = false;
    g_bCountdownCancelled = true;  // 设置取消标志
}

public void OnRoundIsLive()
{
    g_bAutoStartTriggered = false;
    g_bCountdownCancelled = false;  // 重置取消标志
}

public Action Command_ForceStart(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "[!] 此指令只能由玩家在游戏中使用。");
        return Plugin_Handled;
    }

    if (!IsInReady())
    {
        ReplyToCommand(client, "[!] \x04当前不处于准备阶段，无法强制开始。");
        return Plugin_Handled;
    }

    AdminId admin = GetUserAdmin(client);
    bool tempAdmin = false;

    if (admin == INVALID_ADMIN_ID)
    {
        admin = CreateAdmin();
        if (admin == INVALID_ADMIN_ID)
        {
            ReplyToCommand(client, "[!] \x04创建临时管理员失败，操作失败。");
            return Plugin_Handled;
        }
        SetUserAdmin(client, admin, false);
        tempAdmin = true;
    }

    if (!GetAdminFlag(admin, Admin_Ban))
    {
        SetAdminFlag(admin, Admin_Ban, true);
    }

    FakeClientCommand(client, "sm_forcestart");

    DataPack dp;
    CreateDataTimer(0.2, Timer_RemoveAdmin, dp);
    dp.WriteCell(GetClientUserId(client));
    dp.WriteCell(tempAdmin ? admin : INVALID_ADMIN_ID);
    dp.WriteCell(tempAdmin);

    return Plugin_Handled;
}

public Action Timer_RemoveAdmin(Handle timer, DataPack dp)
{
    dp.Reset();
    int client = GetClientOfUserId(dp.ReadCell());
    AdminId tempAdminId = view_as<AdminId>(dp.ReadCell());
    bool tempAdmin = dp.ReadCell();

    if (client > 0)
    {
        AdminId admin = GetUserAdmin(client);
        if (admin != INVALID_ADMIN_ID)
        {
            SetAdminFlag(admin, Admin_Ban, false);
            
            if (tempAdmin && tempAdminId != INVALID_ADMIN_ID)
            {
                SetUserAdmin(client, INVALID_ADMIN_ID, false);
                RemoveAdmin(tempAdminId);
            }
        }
    }

    return Plugin_Stop;
}

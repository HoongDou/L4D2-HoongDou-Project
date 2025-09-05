#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <readyup>

// ====================================================================================================
// >> PLUGIN INFO & DEFINES
// ====================================================================================================

#define L4DTeam_Survivor 2

// ====================================================================================================
// >> GLOBAL VARIABLES
// ====================================================================================================

bool g_bAutoStartTriggered = false;  // 自动开始是否已触发
bool g_bCountdownCancelled = false;  // 倒计时是否被取消
Handle g_hCheckReadyTimer = null;    // 检查准备状态的定时器

// ====================================================================================================
// >> PLUGIN INFORMATION
// ====================================================================================================

public Plugin myinfo =
{
    name = "ReadyUp Extension",
    author = "HoongDou",
    description = "Extends the L4D2 Ready-Up plugin with a highly robust auto-start and a universal sm_fs command.",
    version = "1.6",
    url = "https://github.com/HoongDou/L4D2-HoongDou-Project"
};

// ====================================================================================================
// >> PLUGIN EVENTS
// ====================================================================================================

/**
 * @brief  插件启动时的初始化
 */
public void OnPluginStart()
{
    RegConsoleCmd("sm_fs", Command_ForceStart, "让任何玩家都能强制开始游戏。");
}

/**
 * @brief  所有插件加载完成后的检查
 */
public void OnAllPluginsLoaded()
{
    if (!LibraryExists("readyup"))
    {
        SetFailState("This plugin requires 'readyup.smx'. Please ensure the main ready-up plugin is installed and running.");
    }
}

/**
 * @brief  地图开始时的初始化
 */
public void OnMapStart()
{
    g_bAutoStartTriggered = false;  // 重置自动开始触发标志
    g_bCountdownCancelled = false;  // 重置倒计时取消标志
    
    // 启动检查准备状态的定时器
    if (g_hCheckReadyTimer != null)
    {
        delete g_hCheckReadyTimer;
    }
    g_hCheckReadyTimer = CreateTimer(1.0, Timer_CheckReady, _, TIMER_REPEAT);
}

/**
 * @brief  地图结束时的清理工作
 */
public void OnMapEnd()
{
    if (g_hCheckReadyTimer != null)
    {
        delete g_hCheckReadyTimer;
        g_hCheckReadyTimer = null;
    }
}

// ====================================================================================================
// >> UTILITY FUNCTIONS
// ====================================================================================================

/**
 * @brief  获取生还者团队的人数上限
 * @return 生还者团队人数上限
 */
int GetSurvivorLimit()
{
    ConVar cvarSurvivorLimit = FindConVar("survivor_limit");
    if (cvarSurvivorLimit == null)
    {
        return 4; // 默认值为4人
    }
    return cvarSurvivorLimit.IntValue;
}

/**
 * @brief  计算当前在线的真人生还者数量
 * @return 真人生还者数量（排除电脑玩家）
 */
int GetHumanSurvivorCount()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == L4DTeam_Survivor && !IsFakeClient(i))
        {
            count++;
        }
    }
    return count;
}

// ====================================================================================================
// >> TIMER FUNCTIONS
// ====================================================================================================

/**
 * @brief  定时检查所有真人生还者的准备状态
 * @param  timer 定时器句柄
 * @return 继续执行定时器
 */
public Action Timer_CheckReady(Handle timer)
{
    // 检查是否在准备阶段且未触发自动开始
    if (!IsInReady() || g_bAutoStartTriggered)
    {
        return Plugin_Continue;
    }

    // 获取生还者团队上限和当前真人生还者数量
    int survivorLimit = GetSurvivorLimit();
    int humanSurvivorCount = GetHumanSurvivorCount();
    
    // 如果真人生还者数量未达到团队上限，不触发自动开始
    if (humanSurvivorCount < survivorLimit)
    {
        return Plugin_Continue;
    }

    // 检查是否所有真人生还者都准备就绪
    bool allHumanSurvivorsReady = true;
    bool hasUnreadyHumanPlayer = false;
    
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == L4DTeam_Survivor && !IsFakeClient(i))
        {
            if (!IsReady(i))
            {
                allHumanSurvivorsReady = false;
                hasUnreadyHumanPlayer = true;
            }
        }
    }

    // 如果有真人玩家取消准备，重置倒计时取消标志
    if (hasUnreadyHumanPlayer && g_bCountdownCancelled)
    {
        g_bCountdownCancelled = false;
    }

    // 只有在所有真人生还者准备且倒计时未被取消的情况下才触发自动开始
    if (allHumanSurvivorsReady && !g_bCountdownCancelled)
    {
        PrintToChatAll(" \x04[!] \x01所有生还者已准备就绪 (%d/%d)，开始倒计时！", humanSurvivorCount, survivorLimit);
        ServerCommand("sm_forcestart");
        g_bAutoStartTriggered = true;
    }

    return Plugin_Continue;
}

/**
 * @brief  延迟移除临时管理员权限
 * @param  timer 定时器句柄
 * @param  dp    数据包，包含客户端信息和权限状态
 * @return 停止定时器
 */
public Action Timer_RemoveAdmin(Handle timer, DataPack dp)
{
    dp.Reset();
    int client = GetClientOfUserId(dp.ReadCell());
    AdminId tempAdminId = view_as<AdminId>(dp.ReadCell());
    bool isTempAdmin = dp.ReadCell();
    bool hadOriginalBanPermission = dp.ReadCell();

    if (client > 0 && IsClientInGame(client))
    {
        AdminId admin = GetUserAdmin(client);
        if (admin != INVALID_ADMIN_ID)
        {
            if (isTempAdmin)
            {
                // 临时管理员：完全移除管理员身份
                SetUserAdmin(client, INVALID_ADMIN_ID, false);
                if (tempAdminId != INVALID_ADMIN_ID)
                {
                    RemoveAdmin(tempAdminId);
                }
            }
            else if (!hadOriginalBanPermission)
            {
                // 原有管理员但原本没有Ban权限：只移除Ban权限
                SetAdminFlag(admin, Admin_Ban, false);
            }
            // 如果是原有管理员且原本就有Ban权限，则不做任何操作
        }
    }

    return Plugin_Stop;
}


// ====================================================================================================
// >> READYUP PLUGIN CALLBACKS
// ====================================================================================================

/**
 * @brief  倒计时被取消时的回调函数
 * @param  client         取消倒计时的客户端
 * @param  sDisruptReason 取消原因
 */
public void OnReadyCountdownCancelled(int client, char sDisruptReason)
{
    g_bAutoStartTriggered = false;  // 重置自动开始触发标志
    g_bCountdownCancelled = true;   // 设置倒计时取消标志
}

/**
 * @brief  回合正式开始时的回调函数
 */
public void OnRoundIsLive()
{
    g_bAutoStartTriggered = false;  // 重置自动开始触发标志
    g_bCountdownCancelled = false;  // 重置倒计时取消标志
}

// ====================================================================================================
// >> COMMAND HANDLERS
// ====================================================================================================

/**
 * @brief  处理sm_fs强制开始命令
 * @param  client 执行命令的客户端
 * @param  args   命令参数
 * @return 命令处理结果
 */
public Action Command_ForceStart(int client, int args)
{
    // 控制台无法使用此命令
    if (client == 0)
    {
        ReplyToCommand(client, "[!] 此指令只能由玩家在游戏中使用。");
        return Plugin_Handled;
    }

    // 检查是否在准备阶段
    if (!IsInReady())
    {
        ReplyToCommand(client, "[!] \x04当前不处于准备阶段，无法强制开始。");
        return Plugin_Handled;
    }

    AdminId admin = GetUserAdmin(client);
    bool isOriginalAdmin = (admin != INVALID_ADMIN_ID);  // 是否为原有管理员
    bool hadBanPermission = false;  // 是否原本就有Ban权限
    bool needsCleanup = false;      // 是否需要清理权限
    AdminId tempAdminId = INVALID_ADMIN_ID;  // 临时管理员ID

    // 检查原本是否有Ban权限
    if (isOriginalAdmin)
    {
        hadBanPermission = GetAdminFlag(admin, Admin_Ban);
    }

    // 如果没有管理员权限，创建临时管理员
    if (!isOriginalAdmin)
    {
        admin = CreateAdmin();
        if (admin == INVALID_ADMIN_ID)
        {
            ReplyToCommand(client, "[!] \x04创建临时管理员失败，操作失败。");
            return Plugin_Handled;
        }
        SetUserAdmin(client, admin, false);
        tempAdminId = admin;
        needsCleanup = true;
    }

    // 如果是原有管理员但没有Ban权限，需要临时添加
    else if (!hadBanPermission)
    {
        needsCleanup = true;
    }

    // 确保有Ban权限（执行forcestart需要此权限）
    if (!GetAdminFlag(admin, Admin_Ban))
    {
        SetAdminFlag(admin, Admin_Ban, true);
    }

    PrintToChatAll(" \x04[!] \x05%N \x01发起了强制开始！", client);
    FakeClientCommand(client, "sm_forcestart");

    // 如果需要清理权限，延迟执行
    if (needsCleanup)
    {
        DataPack dp;
        CreateDataTimer(0.2, Timer_RemoveAdmin, dp);
        dp.WriteCell(GetClientUserId(client));
        dp.WriteCell(tempAdminId);  // 临时管理员ID（如果是临时的）
        dp.WriteCell(!isOriginalAdmin);  // 是否为临时管理员
        dp.WriteCell(hadBanPermission);  // 是否原本就有Ban权限
    }

    return Plugin_Handled;
}

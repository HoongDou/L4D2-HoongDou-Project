#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_VERSION "1.3"

// 全局变量
ConVar g_hGameMode;             // 用于存储 mp_gamemode 的句柄
ConVar g_hAutoloaderConfig;     // 主配置文件 (例如 "zonemod等")
ConVar g_hAutoloaderPreExec;    // 预备配置文件 (在主配置前执行)

public Plugin myinfo = 
{
    name = "Confogl Autoloader",
    author = "D4rKr0W, 海洋空氣, HoongDou",
    description = "当游戏模式切换到对抗(versus/coop)时，自动加载Confogl配置。",
    version = PLUGIN_VERSION,
    url = "http://code.google.com/p/confogl"
};

/**
 * @brief 插件启动时调用，用于初始化所有内容。
 */
public void OnPluginStart()
{
    // 创建版本号CVar
    CreateConVar("confogl_loader_ver", PLUGIN_VERSION, "Confogl Autoloader插件版本", FCVAR_SPONLY|FCVAR_NOTIFY|FCVAR_DONTRECORD);

    // 创建功能性CVar，用于指定要加载的配置文件名
    g_hAutoloaderConfig = CreateConVar("confogl_autoloader_config", "", "需要自动加载的主配置文件 (例如 zonemod)");
    g_hAutoloaderPreExec = CreateConVar("confogl_autoloader_execcfg", "", "在加载主配置前需要执行的预备配置文件");

    // 找到 gamemode CVar并获取其句柄
    g_hGameMode = FindConVar("mp_gamemode");
    
    // Hook gammemode CVar变动，当模式改变时调用函数
    if (g_hGameMode != null)
    {
        g_hGameMode.AddChangeHook(ConVarChange_GameMode);
    }
}

/**
 * @brief 在服务器所有配置加载完成后调用。
 *        用于确保在插件重载等情况下，也能正确检查一次当前的游戏模式。
 */
public void OnConfigsExecuted()
{
    // 手动执行一次检查，以处理插件加载时游戏已经是目标模式的情况
    CheckAndExecuteConfig();
}

/**
 * @brief 地图开始时调用。
 */
public void OnMapStart()
{
    // 地图开始时，也检查一次游戏模式并执行相应配置，作为双重保险。
    CheckAndExecuteConfig();
}

/**
 * @brief 当 mp_gamemode 的值发生改变时，此回调函数会被触发。
 */
public void ConVarChange_GameMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // 游戏模式发生了变化，立即检查并执行配置
    CheckAndExecuteConfig();
}

/**
 * @brief 检查当前游戏模式并执行相应配置的核心逻辑函数。
 */
void CheckAndExecuteConfig()
{
    char sGameMode[32];
    g_hGameMode.GetString(sGameMode, sizeof(sGameMode));

    // 检查当前是否为 Versus / Coop 模式
    if (IsVersusMode(sGameMode))
    {
        // 是 Versus / Coop 模式，准备加载Confogl配置
        char sPreExec[PLATFORM_MAX_PATH];
        g_hAutoloaderPreExec.GetString(sPreExec, sizeof(sPreExec));

        // 1. 如果设置了预备配置文件，则先执行它
        if (sPreExec[0] != '\0')
        {
            ServerCommand("exec %s", sPreExec);
        }

        char sMainConfig[PLATFORM_MAX_PATH];
        g_hAutoloaderConfig.GetString(sMainConfig, sizeof(sMainConfig));

        // 2. 如果设置了主配置文件，则重置比赛并强制加载它
        if (sMainConfig[0] != '\0')
        {
            ServerCommand("sm_resetmatch");
            ServerCommand("sm_forcematch %s", sMainConfig);
        }
    }
    else
    {
        // 不是匹配的模式，执行重置，以确保卸载掉任何可能残留的Confogl设置。
        // 执行清理。
        ServerCommand("sm_resetmatch");
    }
}

/**
 * @brief 一个辅助函数，用于判断给定的游戏模式字符串是否为合作/对抗模式。
 * @param mode      游戏模式字符串。
 * @return          如果是 "coop" 或 “versus” 则返回 true，否则返回 false。
 */
bool IsVersusMode(const char[] mode)
{
    return strcmp(mode, "coop", false) == 0 || strcmp(mode, "versus", false) == 0;
}

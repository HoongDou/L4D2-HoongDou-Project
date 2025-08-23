#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <datapack>

// ====================================================================================================
// >> PLUGIN INFO & DEFINES
// ====================================================================================================


#define VERSION "5.1"
#define DEBUG 1

#define FORCE_SPAWN_TIMEOUT 1.25      // 强制生成时，每种特感的重试超时时间 (秒)
#define FORCE_SPAWN_MAX_ATTEMPTS 10   // 强制生成时，每种特感的最大重试次数

// 特感id定义
#define SMOKER  1
#define BOOMER  2
#define HUNTER  3
#define SPITTER 4
#define JOCKEY  5
#define CHARGER 6
#define SI_CLASS_SIZE 7

// 导航网格属性
#define	TERROR_NAV_NO_NAME1				(1 << 0)
#define	TERROR_NAV_EMPTY				(1 << 1)
#define	TERROR_NAV_STOP_SCAN			(1 << 2)
#define	TERROR_NAV_NO_NAME2				(1 << 3)
#define	TERROR_NAV_NO_NAME3				(1 << 4)
#define	TERROR_NAV_BATTLESTATION		(1 << 5)
#define	TERROR_NAV_FINALE				(1 << 6)
#define	TERROR_NAV_PLAYER_START			(1 << 7)
#define	TERROR_NAV_BATTLEFIELD			(1 << 8)
#define	TERROR_NAV_IGNORE_VISIBILITY	(1 << 9)
#define	TERROR_NAV_NOT_CLEARABLE		(1 << 10)
#define	TERROR_NAV_CHECKPOINT			(1 << 11)    // 安全区
#define	TERROR_NAV_OBSCURED				(1 << 12)
#define	TERROR_NAV_NO_MOBS				(1 << 13)
#define	TERROR_NAV_THREAT				(1 << 14)
#define	TERROR_NAV_RESCUE_VEHICLE		(1 << 15)    // 救援载具
#define	TERROR_NAV_RESCUE_CLOSET		(1 << 16)    // 救援机关
#define	TERROR_NAV_ESCAPE_ROUTE			(1 << 17)
#define	TERROR_NAV_DOOR					(1 << 18)
#define	TERROR_NAV_NOTHREAT				(1 << 19)
#define	TERROR_NAV_LYINGDOWN			(1 << 20)
#define	TERROR_NAV_COMPASS_NORTH		(1 << 24)
#define	TERROR_NAV_COMPASS_NORTHEAST	(1 << 25)
#define	TERROR_NAV_COMPASS_EAST			(1 << 26)
#define	TERROR_NAV_COMPASS_EASTSOUTH	(1 << 27)
#define	TERROR_NAV_COMPASS_SOUTH		(1 << 28)
#define	TERROR_NAV_COMPASS_SOUTHWEST	(1 << 29)
#define	TERROR_NAV_COMPASS_WEST			(1 << 30)
#define	TERROR_NAV_COMPASS_WESTNORTH	(1 << 31)

public Plugin myinfo = 
{
    name = "L4D2 Advanced SI Spawn Control",
    author = "HoongDou",
    description = "用于导演系统和nav的刷特，保证优先高处刷特和不在视野范围内",
    version = VERSION
};

// ====================================================================================================
// >> DATA STRUCTURES
// ====================================================================================================

/**
 * @struct SpawnCandidate
 * @brief  存储一个特感生成点的信息
 */
enum struct SpawnCandidate
{
    float pos[3];               // 生成点坐标
    float flow;                 // 生成点所在的流程距离
    int associatedSurvivor;     // 与之关联的幸存者
}


// ====================================================================================================
// >> GLOBAL VARIABLES
// ====================================================================================================


// Gamedata Handles & Offsets
// 必须在使用它们的 methodmap 之前声明
TheNavAreas g_pTheNavAreas;                     // 指向游戏内 TheNavAreas 对象的指针
Handle g_hSDKFindRandomSpot;                    // 用于调用 TerrorNavArea::FindRandomSpot 的 SDKCall 句柄
int g_iSpawnAttributesOffset;                   // SpawnAttributes 内存偏移量
int g_iFlowDistanceOffset;                      // FlowDistance 内存偏移量
int g_iNavCountOffset;                          // NavCount 内存偏移量

// 全局变量
// ConVar Handles
ConVar g_cvSpecialLimit[SI_CLASS_SIZE];         // 各特感数量限制
ConVar g_cvMaxSILimit;                          // 最大特感总数
ConVar g_cvSpawnTime;                           // 每波生成的时间间隔
ConVar g_cvFirstSpawnTime;                      // 离开安全区后的首次生成延迟
ConVar g_cvKillSITime;                          // 清理不活动特感的超时时间
ConVar g_cvBlockSpawn;                          // 是否拦截非本插件的生成
ConVar g_cvHighGroundPriority;                  // 是否优先在高处生成
ConVar g_cvMinSpawnDist;                        // 最小生成距离
ConVar g_cvMaxSpawnDist;                        // 最大生成距离
ConVar g_cvMaxFlowDiff;                         // 最大流程差
ConVar g_cvNumGroups;                           // 生成点分组数量
ConVar g_h_zMaxPlayerZombies;                   // 游戏原生 cvar "z_max_player_zombies" 的句柄


// Cached ConVar Values
int g_iSpecialLimit[SI_CLASS_SIZE];             // 各特感数量限制 (缓存值)
int g_iMaxSILimit;                              // 最大特感总数 (缓存值)
float g_fSpawnTime;                             // 每波生成的时间间隔 (缓存值)
float g_fFirstSpawnTime;                        // 首次生成延迟 (缓存值)
float g_fKillSITime;                            // 清理超时时间 (缓存值)
bool g_bHighGroundPriority;                     // 是否优先高处 (缓存值)
float g_fMinSpawnDist, g_fMaxSpawnDist;         // 最小/最大生成距离 (缓存值)
float g_fMaxFlowDiff;                           // 最大流程差 (缓存值)
int g_iNumGroups;                               // 分组数量 (缓存值)

// Plugin State & Timers
bool g_bReadyUpExists;				            // readyup插件是否存在
bool g_bIsRoundLive;                            // 标记 readyup 是否已宣布比赛开始
bool g_bSpawnLogicStarted;                      // 标记刷特逻辑是否已启动,代表幸存者是否已离开安全区
bool g_bFinalMap;                               // 当前是否为终局地图
bool g_bCanSpawn;                               // 插件内部生成许可标志，用于区分原生生成
bool g_bBlockSpawn;                             // 是否拦截原生生成的缓存值
bool g_bMark[MAXPLAYERS+1];                     // 标记由本插件生成的特感
float g_fSpecialActionTime[MAXPLAYERS+1];       // 记录特感上次活动时间
ArrayList g_hSpawnCandidateList;                // 存储当前有效的生成候选点列表
Handle g_hMasterSpawnTimer;                     // 主生成循环计时器

// Spawn Class Blocking
bool g_bClassBlocked[SI_CLASS_SIZE];            // 标记某个种类的特感是否因生成失败被临时禁用
float g_fClassBlockTime[SI_CLASS_SIZE];         // 临时禁用的解锁时间


// ====================================================================================================
// >> GAMEDATA METHODMAPS
// ====================================================================================================

// Methodmap 必须与 Gamedata 定义完全匹配

methodmap TheNavAreas
{
    /**
     * @brief  获取导航区域的总数
     * @return 导航区域数量
     */
    public int Count() {
        // 从 g_iNavCountOffset 读取区域数量
        return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iNavCountOffset), NumberType_Int32);
    }

    /**
     * @brief  解引用以获取导航区域数组的基地址
     * @return 导航区域数组的地址
     */
    public Address Dereference() {
		return LoadFromAddress(view_as<Address>(this), NumberType_Int32);
	}

    /**
     * @brief  根据索引获取一个具体的导航区域
     * @param index 索引
     * @return NavArea 对象
     */
	public NavArea GetArea(int index) {
		Address areaArray = this.Dereference();
		Address areaAddress = LoadFromAddress(areaArray + view_as<Address>(index * 4), NumberType_Int32);
		return view_as<NavArea>(areaAddress);
	}
};

methodmap NavArea
{
    /**
     * @brief  检查 NavArea 对象是否为空
     * @return 如果为空则返回 true
     */
    public bool IsNull() {
        return view_as<Address>(this) == Address_Null;
    }

    /**
     * @brief  通过 SDKCall 调用 gamedata 中的 "TerrorNavArea::FindRandomSpot" 获取区域内的随机生成点
     * @param fPos  用于接收返回坐标的数组
     */
    public void GetSpawnPos(float fPos[3]) {
        SDKCall(g_hSDKFindRandomSpot, this, fPos);
    }

    /**
     * @brief  获取导航区域的生成属性 (SpawnAttributes)
     */
    property int SpawnAttributes {
        public get() {
            // 从 g_iSpawnAttributesOffset 读取生成属性
            return LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iSpawnAttributesOffset), NumberType_Int32);
        }
    }

    /**
     * @brief  获取导航区域的流程距离 (FlowDistance)
     * @return 流程距离浮点值
     */
    public float GetFlow() {
        // 从 g_iFlowDistanceOffset 读取流程距离
        return view_as<float>(LoadFromAddress(view_as<Address>(this) + view_as<Address>(g_iFlowDistanceOffset), NumberType_Int32));
    }
}


// ====================================================================================================
// >> MAIN FUNCTIONS
// ====================================================================================================

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("L4D2Direct_GetFlowDistance"); // 标记 L4D2Direct 库为可选
    return APLRes_Success;
}

public void OnPluginStart()
{
    CreateConVar("l4d2_si_spawn_control_fusion_version", VERSION, "Version of the Advanced SI Spawn Control plugin.", FCVAR_NOTIFY | FCVAR_DONTRECORD);

    //  创建并绑定 ConVars
    g_cvSpecialLimit[HUNTER]  = CreateConVar("l4d2_si_spawn_control_hunter_limit", "2", "Hunter limit.", _, true, 0.0);
    g_cvSpecialLimit[JOCKEY]  = CreateConVar("l4d2_si_spawn_control_jockey_limit", "2", "Jockey limit.", _, true, 0.0);
    g_cvSpecialLimit[SMOKER]  = CreateConVar("l4d2_si_spawn_control_smoker_limit", "1", "Smoker limit.", _, true, 0.0);
    g_cvSpecialLimit[BOOMER]  = CreateConVar("l4d2_si_spawn_control_boomer_limit", "1", "Boomer limit.", _, true, 0.0);
    g_cvSpecialLimit[SPITTER] = CreateConVar("l4d2_si_spawn_control_spitter_limit", "1", "Spitter limit.", _, true, 0.0);
    g_cvSpecialLimit[CHARGER] = CreateConVar("l4d2_si_spawn_control_charger_limit", "1", "Charger limit.", _, true, 0.0);
    g_cvMaxSILimit            = CreateConVar("l4d2_si_spawn_control_max_specials", "6", "Max SI limit.", _, true, 0.0);
    g_cvSpawnTime             = CreateConVar("l4d2_si_spawn_control_spawn_time", "15.0", "Time between spawn waves.", _, true, 1.0);
    g_cvFirstSpawnTime        = CreateConVar("l4d2_si_spawn_control_first_spawn_time", "0.1", "Delay for the first spawn after leaving the safe area.", _, true, 0.1);
    g_cvKillSITime            = CreateConVar("l4d2_si_spawn_control_kill_si_time", "35.0", "Auto kill SI if they are inactive.", _, true, 0.0);
    g_cvBlockSpawn            = CreateConVar("l4d2_si_spawn_control_block_other_si_spawn", "1", "Block SI spawns not from this plugin.", _, true, 0.0, true, 1.0);
    g_cvHighGroundPriority    = CreateConVar("l4d2_si_spawn_control_high_ground", "1", "1=Enable high-ground priority for spawns, 0=Disable.", _, true, 0.0, true, 1.0);
    g_cvMinSpawnDist          = CreateConVar("l4d2_si_spawn_control_min_dist", "120.0", "Minimum distance from a survivor to spawn.", _, true, 100.0);
    g_cvMaxSpawnDist          = CreateConVar("l4d2_si_spawn_control_max_dist", "650.0", "Maximum distance from a survivor to spawn.", _, true, 500.0);
    g_cvMaxFlowDiff           = CreateConVar("l4d2_si_spawn_control_max_flow_diff", "800.0", "Maximum flow distance difference from a survivor to spawn.", _, true, 200.0);
    g_cvNumGroups             = CreateConVar("l4d2_si_spawn_control_num_groups", "20", "Number of spawn groups/zones to create around survivors.", _, true, 1.0, true, 100.0);

    // 解锁并同步原生 ConVar
    g_h_zMaxPlayerZombies = FindConVar("z_max_player_zombies");
    if (g_h_zMaxPlayerZombies != null)
    {
        g_h_zMaxPlayerZombies.Flags &= ~FCVAR_CHEAT; // 移除作弊保护
        g_h_zMaxPlayerZombies.SetBounds(ConVarBound_Upper, false); // 移除上限
        LogMessage("[AdvSpawn] Successfully unlocked 'z_max_player_zombies'.");
        g_cvMaxSILimit.AddChangeHook(OnMaxSIChange); // 添加监听，使其与 "l4d2_si_spawn_control_max_specials" Cvar 同步
    }
    else
    {
        LogError("[AdvSpawn] FATAL ERROR: Could not find ConVar 'z_max_player_zombies'.");
    }

    // 注册 ConVar 变化钩子
    for (int i = 1; i < SI_CLASS_SIZE; i++) g_cvSpecialLimit[i].AddChangeHook(ConVarChanged);
    g_cvMaxSILimit.AddChangeHook(ConVarChanged);
    g_cvSpawnTime.AddChangeHook(ConVarChanged);
    g_cvFirstSpawnTime.AddChangeHook(ConVarChanged);
    g_cvKillSITime.AddChangeHook(ConVarChanged);
    g_cvBlockSpawn.AddChangeHook(ConVarChanged);
    g_cvHighGroundPriority.AddChangeHook(ConVarChanged);
    g_cvMinSpawnDist.AddChangeHook(ConVarChanged);
    g_cvMaxSpawnDist.AddChangeHook(ConVarChanged);
    g_cvMaxFlowDiff.AddChangeHook(ConVarChanged);
    g_cvNumGroups.AddChangeHook(ConVarChanged);
    
    // 注册事件钩子
    HookEvent("round_start", Event_OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
    
    // 初始化 Gamedata
    InitGamedata();

    // 创建全局计时器
    CreateTimer(1.0, KillSICheck_Timer, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(1.0, Timer_ClearBlockedClasses, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE); 
    
    // 判断readyup插件是否存在
	if (LibraryExists("readyup"))
	{
		g_bReadyUpExists = true;
		// readyup插件存在
        PrintToServer("[AdvSpawn] Detected l4d2_ready_up plugin. Will wait for 'go live' signal.");
	}
	else
	{
		g_bReadyUpExists = false;
        PrintToServer("[AdvSpawn] l4d2_ready_up not detected. Using default 'leave safe area' trigger.");
	}
    // 自动执行配置文件
    AutoExecConfig(true, "l4d2_si_spawn_control_fusion");
}


public void OnConfigsExecuted() 
{ 
    GetCvars(); // 配置文件加载后，缓存所有 CVar 值
}

public void OnMapStart() 
{ 
    Reset(); 
    g_bFinalMap = L4D_IsMissionFinalMap();
    // 延迟同步特感上限，确保设置覆盖其他插件或地图配置
    CreateTimer(1.0, Timer_SetMaxSpecials, _, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd() 
{ 
    Reset(); 
}

// ====================================================================================================
// >> GAMEDATA INITIALIZATION
// ====================================================================================================

/**
 * @brief  加载 Gamedata 文件，获取原生函数和变量的地址/偏移量
 * @note   如果失败，插件将进入错误状态并停止运行
 */
void InitGamedata()
{
    Handle hGameConf = LoadGameConfigFile("l4d2_si_spawn_control"); 
    if (hGameConf == null)
    {
        SetFailState("Gamedata Error: Could not read 'l4d2_si_spawn_control.txt'. Please ensure it exists in addons/sourcemod/gamedata/ and the name is correct in the plugin.");
    }

    // 获取 TheNavAreas 对象的地址
    g_pTheNavAreas = view_as<TheNavAreas>(GameConfGetAddress(hGameConf, "TheNavAreas"));
    if (g_pTheNavAreas.Dereference() == Address_Null) SetFailState("Gamedata Error: Failed to find address 'TheNavAreas'");

    // 获取内存偏移量
    g_iSpawnAttributesOffset = GameConfGetOffset(hGameConf, "TerrorNavArea::SpawnAttributes");
    if (g_iSpawnAttributesOffset == -1) SetFailState("Gamedata Error: Failed to find offset 'TerrorNavArea::SpawnAttributes'");

    g_iFlowDistanceOffset = GameConfGetOffset(hGameConf, "TerrorNavArea::FlowDistance");
    if (g_iFlowDistanceOffset == -1) SetFailState("Gamedata Error: Failed to find offset 'TerrorNavArea::FlowDistance'");

    g_iNavCountOffset = GameConfGetOffset(hGameConf, "TheNavAreas::Count");
    if (g_iNavCountOffset == -1) SetFailState("Gamedata Error: Failed to find offset 'TheNavAreas::Count'");

    /**
    * 创建 SDKCall (使用 gamedata 中的函数签名)
    * 根据 gamedata, TerrorNavArea::FindRandomSpot(void) const -> 返回一个 Vector
	* 这里不能用SDKCall_Static
    */
    StartPrepSDKCall(SDKCall_Raw);
    if (!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TerrorNavArea::FindRandomSpot"))
    {
        SetFailState("Gamedata Error: Failed to find signature 'TerrorNavArea::FindRandomSpot'");
    }
    // 设置返回类型为 Vector, 通过值传递 (函数直接返回值)
    PrepSDKCall_SetReturnInfo(SDKType_Vector, SDKPass_ByValue);
    // 此函数没有参数，所以不需要 AddParameter
    g_hSDKFindRandomSpot = EndPrepSDKCall();
    if (g_hSDKFindRandomSpot == null)
    {
        SetFailState("Failed to create SDKCall for 'TerrorNavArea::FindRandomSpot'");
    }
    
    delete hGameConf;
}

// ====================================================================================================
// >> CORE LOGIC OF SPAWNING SI
// ====================================================================================================

/**
 * @brief  主生成计时器，按设定的时间间隔循环触发-外循环
 * @param  timer  计时器句柄
 * @return Plugin action
 */
public Action MasterSpawnTimer(Handle timer)
{
    // 1. 检查基本生成条件
    if (!g_bSpawnLogicStarted) return Plugin_Continue; // 幸存者未离开安全区
    if (L4D_IsMissionFinalMap() && L4D2_GetCurrentFinaleStage() == 1) return Plugin_Continue; // 终局救援已开始
    if (GetSurvivorCount() == 0) return Plugin_Continue; // 场上没有存活的幸存者

    // 2. 计算需要补充的特感数量
    int currentSI = GetAllSpecialsTotal();
    int siToSpawn = g_iMaxSILimit - currentSI;

    if (siToSpawn <= 0) return Plugin_Continue;

    // 3. 调用分组生成逻辑
    #if DEBUG
    PrintToServer("[AdvSpawn] Timer ticked. Need to spawn %d SI.", siToSpawn);
    #endif
    SpawnSpecialsInGroups(siToSpawn);

    return Plugin_Continue;
}

/**
 * @brief  两阶段生成法：根据候选列表，以分组方式生成指定数量的特感
 * @param  numToSpawn 需要生成的特感数量
 * @note   结合散布生成候选点位（第一阶段）和数量保证（第二阶段）
 */
void SpawnSpecialsInGroups(int numToSpawn)
{
    // 准备阶段：构建并排序候选列表
    #if DEBUG
    float startTime = GetEngineTime();
    #endif
    delete g_hSpawnCandidateList;
    g_hSpawnCandidateList = BuildAndSortCandidateList();
    int candidateCount = g_hSpawnCandidateList.Length;
    #if DEBUG
    PrintToServer("[AdvSpawn] BuildAndSortCandidateList took %.4f seconds. Found %d candidates.", GetEngineTime() - startTime, candidateCount);
    #endif

    if (candidateCount == 0)
    {
        #if DEBUG
        PrintToServer("[AdvSpawn] No valid candidates found. Forcing spawn ahead of leader.");
        #endif
        ForceSpawnAheadOfLeader(numToSpawn); // 如果没有候选点，则启动后备方案
        return;
    }

    // 分组阶段: 将所有候选点均匀分配到指定数量的组中
    int numGroups = g_iNumGroups;
    if (candidateCount < numGroups) {
        numGroups = candidateCount;
    }

    ArrayList[] hGroupedCandidates = new ArrayList[numGroups];
    for (int i = 0; i < numGroups; i++) {
        hGroupedCandidates[i] = new ArrayList(sizeof(SpawnCandidate));
    }
    for (int i = 0; i < candidateCount; i++) {
        SpawnCandidate candidate;
        g_hSpawnCandidateList.GetArray(i, candidate);
        hGroupedCandidates[i % numGroups].PushArray(candidate);
    }

    int spawnedCount = 0;
    bool[] bGroupHasSpawned = new bool[numGroups]; // 标记每个组是否已成功生成过

    // 第一阶段: 理想散布
    // 目标：在尽可能多的不同组中各生成一个特感，以实现位置上的最大化分散
    #if DEBUG
    PrintToServer("[AdvSpawn] Starting Phase 1: Ideal Scatter. Trying to spawn in %d unique groups.", numGroups);
    #endif
    
    ArrayList hGroupOrder = new ArrayList(); // 随机化组的遍历顺序
    for (int i = 0; i < numGroups; i++) hGroupOrder.Push(i);
    hGroupOrder.SortCustom(Sort_RandomInt);

    for (int i = 0; i < numGroups && spawnedCount < numToSpawn; i++)
    {
        int groupIndex = hGroupOrder.Get(i);
        ArrayList hCurrentGroup = hGroupedCandidates[groupIndex];

        for (int j = 0; j < hCurrentGroup.Length; j++)
        {
            int classToSpawn = GetSpawnClass();
            if (classToSpawn <= 0) break; // 没有可生成的特感类型了

            SpawnCandidate spawnPoint;
            hCurrentGroup.GetArray(j, spawnPoint);

            g_bCanSpawn = true;
            int entity = L4D2_SpawnSpecial(classToSpawn, spawnPoint.pos, NULL_VECTOR);
            g_bCanSpawn = false;

            if (IsValidEntity(entity))
            {
                spawnedCount++;
                bGroupHasSpawned[groupIndex] = true;
                g_bMark[entity] = true;
                g_fSpecialActionTime[entity] = GetEngineTime();
                //  调用 LogSpawn 进行实时日志记录
                LogSpawn(entity, classToSpawn, spawnPoint.pos[2], spawnedCount, numToSpawn, "Phase 1");
                CreateTimer(0.1, Timer_ValidateSpawn, CreateDataPackFromSpawnInfo(entity, classToSpawn, spawnedCount, numToSpawn, "Phase 1"));
                break; // 这个组成功了，处理下一个组
            }
            else
            {
                LogSpawn(0, classToSpawn, 0.0, spawnedCount, numToSpawn, "Phase 1 Failure");
                g_bClassBlocked[classToSpawn] = true;
                g_fClassBlockTime[classToSpawn] = GetEngineTime() + 10.0;
            }
        }
    }
    
    // 第二阶段: 补足数量
    // 目标：如果第一阶段未能生成足够的特感，则在尚未生成过的候选点中继续尝试，直到数量达标
    if (spawnedCount < numToSpawn)
    {
        #if DEBUG
        PrintToServer("[AdvSpawn] Phase 1 spawned %d SI. Starting Phase 2: Fill Gaps for remaining %d SI.", spawnedCount, numToSpawn - spawnedCount);
        #endif
        for (int i = 0; i < candidateCount && spawnedCount < numToSpawn; i++)
        {
            if (bGroupHasSpawned[i % numGroups]) continue; // 跳过已生成过的组中的点，以保持分散性

            int classToSpawn = GetSpawnClass();
            if (classToSpawn <= 0) break;

            SpawnCandidate spawnPoint;
            g_hSpawnCandidateList.GetArray(i, spawnPoint);

            g_bCanSpawn = true;
            int entity = L4D2_SpawnSpecial(classToSpawn, spawnPoint.pos, NULL_VECTOR);
            g_bCanSpawn = false;

            if (IsValidEntity(entity))
            {
                spawnedCount++;
                bGroupHasSpawned[i % numGroups] = true;
                g_bMark[entity] = true;
                g_fSpecialActionTime[entity] = GetEngineTime();

                LogSpawn(entity, classToSpawn, spawnPoint.pos[2], spawnedCount, numToSpawn, "Phase 2");
                CreateTimer(0.1, Timer_ValidateSpawn, CreateDataPackFromSpawnInfo(entity, classToSpawn, spawnedCount, numToSpawn, "Phase 2"));
            }
            else
            {
                g_bClassBlocked[classToSpawn] = true;
                g_fClassBlockTime[classToSpawn] = GetEngineTime() + 10.0;
            }
        }
    }

    #if DEBUG
    PrintToServer("[AdvSpawn] Spawn wave finished. Requested %d, actually spawned %d SI.", numToSpawn, spawnedCount);
    #endif

    // 后备方案: 强制生成
    // 目标：如果补足数进行尝试生成后，该点位仍然被导演系统拒绝，则启用强制生成方法去补足特感数量
    if (spawnedCount < numToSpawn)
    {
        #if DEBUG
        PrintToServer("[AdvSpawn] All methods were insufficient. Forcing spawn for the remaining %d SI.", numToSpawn - spawnedCount);
        #endif
        ForceSpawnAheadOfLeader(numToSpawn - spawnedCount);
    }
    
    // 清理内存
    for (int i = 0; i < numGroups; i++) delete hGroupedCandidates[i];
    delete hGroupOrder;
}

/**
 * @brief  遍历所有导航区域，构建一个符合条件的生成候选点列表
 * @return 一个包含所有有效候选点的 ArrayList
 */
ArrayList BuildAndSortCandidateList()
{
    ArrayList candidateList = new ArrayList(sizeof(SpawnCandidate));
    
    // 获取所有存活的生还者信息
    int survivors[MAXPLAYERS+1];
    int survivorCount = GetAliveSurvivors(survivors);
    if (survivorCount == 0) return candidateList;

    float survivorPos[MAXPLAYERS+1][3];
    float survivorFlow[MAXPLAYERS+1];
    bool useFlow = LibraryExists("l4d2direct");
    // 如果没有l4d2direct，则无法使用flow逻辑
    for (int i = 0; i < survivorCount; i++)
    {
        GetClientAbsOrigin(survivors[i], survivorPos[i]);
        survivorFlow[i] = useFlow ? L4D2Direct_GetFlowDistance(survivors[i]) : 0.0;
    }

    bool bFinaleArea = g_bFinalMap && L4D2_GetCurrentFinaleStage() > 0;
    // 遍历所有导航区域
    for (int i = 0; i < g_pTheNavAreas.Count(); i++)
    {
        NavArea pNavArea = g_pTheNavAreas.GetArea(i);
        if (pNavArea.IsNull()) continue;

        // 过滤1: 检查区域属性是否适合生成, 通过 IsValidFlags 过滤掉安全区和其他不合适的区域
        if (!IsValidFlags(pNavArea.SpawnAttributes, bFinaleArea)) continue;
        
        float navPos[3];
        pNavArea.GetSpawnPos(navPos);
        
        if (IsVectorZero(navPos) || WillStuck(navPos)) continue;

        // 过滤2: 检查该点是否在任何一个幸存者的距离和流程范围内
        float navFlow = pNavArea.GetFlow();
        bool isCandidateValid = false;
        // 检查该点相对于所有生还者的有效性
        for (int s = 0; s < survivorCount; s++)
        {

            // 检查流程距离
            if (useFlow && FloatAbs(navFlow - survivorFlow[s]) > g_fMaxFlowDiff) continue;

            // 检查直线距离
            float dist = GetVectorDistance(navPos, survivorPos[s]);
            if (dist > g_fMaxSpawnDist || dist < g_fMinSpawnDist) continue;
            
            // 只要有一个生还者满足距离要求，这个点就可能有效
            isCandidateValid = true;
            break; 
        }

        if (!isCandidateValid) continue;

        // 过滤3: 最终视野检查，确保该点对所有的生还者都不可见
        bool isVisibleToAnySurvivor = false;
        for (int s = 0; s < survivorCount; s++)
        {
            if (IsPositionVisibleToClient(navPos, survivors[s]))
            {
                isVisibleToAnySurvivor = true;
                break;
            }
        }
        
        if (isVisibleToAnySurvivor) continue;

        // 通过所有检查，加入候选列表
        SpawnCandidate candidate;
        candidate.pos = navPos;
        candidate.flow = navFlow;
        // 这里可以不关联特定幸存者，因为已经对所有幸存者做了检查
        //candidate.associatedSurvivor = survivors[0]; 
        candidateList.PushArray(candidate);
    }

    // 排序: 根据 CVar 决定是优先高处还是随机打乱
    if (g_bHighGroundPriority) 
    {
        candidateList.SortCustom(Sort_ByHeightDesc);
    } else 
    {
        candidateList.SortCustom(Sort_RandomInt);
    }

    return candidateList;
}

// Fallback Spawning Mechanism

/**
 * @brief  后备生成方案：当常规生成失败时，启动此方案强制在幸存者前方生成
 * @param  numToSpawn 需要生成的数量
 * @note   此函数通过创建一个链式计时器来逐个生成特感，避免单帧生成过多实体
 */
void ForceSpawnAheadOfLeader(int numToSpawn)
{
    if (GetSurvivorCount() == 0 || numToSpawn <= 0) return;

    #if DEBUG
    PrintToServer("[AdvSpawn] Initiating force spawn sequence for %d SI.", numToSpawn);
    #endif

    // 创建一个DataPack来传递状态
    DataPack pack = new DataPack();
    pack.WriteCell(numToSpawn); // 剩余需生成的数量
    pack.WriteCell(numToSpawn); // 总共需生成的数量 (用于日志)
    
    CreateTimer(0.1, Timer_ForceSpawnNext, pack); // 启动第一个生成计时器
}

/**
 * @brief  强制生成的链式计时器回调，每次尝试生成一个特感
 * @param  timer  计时器句柄
 * @param  pack   数据包，包含剩余数量和总数量
 * @return Plugin_Stop to prevent the timer from repeating.
 */
public Action Timer_ForceSpawnNext(Handle timer, DataPack pack)
{
    pack.Reset();
    int remainingToSpawn = pack.ReadCell();
    int totalToSpawnForLog = pack.ReadCell();

    // 尝试生成一只
    int classToSpawn = GetSpawnClass();
    if (classToSpawn > 0)
    {
		float spawnPos[3]; // 定义一个数组来接收坐标
        int entity = AttemptForceSpawnWithRetries(classToSpawn, spawnPos);
        if (entity > 0)
        {
            g_bMark[entity] = true;
            g_fSpecialActionTime[entity] = GetEngineTime();

            // 使用正确的当前计数值来创建验证计时器
            int currentCount = (totalToSpawnForLog - remainingToSpawn) + 1;
            LogSpawn(entity, classToSpawn, spawnPos[2], currentCount, totalToSpawnForLog, "Force Spawn");
            CreateTimer(0.1, Timer_ValidateSpawn, CreateDataPackFromSpawnInfo(entity, classToSpawn, currentCount, totalToSpawnForLog, "Force Spawn"));
        }
        else
        {
            g_bClassBlocked[classToSpawn] = true; // 如果所有重试都失败了
            g_fClassBlockTime[classToSpawn] = GetEngineTime() + 10.0;
        }
    }

    remainingToSpawn--;

    // 如果还有需要生成的，则创建下一个计时器
    if (remainingToSpawn > 0)
    {
        pack.Reset();
        pack.WriteCell(remainingToSpawn);
        pack.WriteCell(totalToSpawnForLog);
        CreateTimer(0.1, Timer_ForceSpawnNext, pack); // 创建下一个计时器，延迟0.1秒
    }

    return Plugin_Stop;
}


/**
 * @brief  尝试强制生成一个指定的特感，带有重试和超时机制
 * @param  classToSpawn 需要生成的特感类型ID
 * @param  spawnPos 生成的z轴坐标
 * @return 成功则返回生成的实体ID，失败则返回0
 */
int AttemptForceSpawnWithRetries(int classToSpawn, float spawnPos[3])
{
    float startTime = GetEngineTime();
    char sClassName[32];
    GetZombieClassName(classToSpawn, sClassName, sizeof(sClassName));

    // 初始化传进来的z轴坐标数组，以防万一
    spawnPos[0] = spawnPos[1] = spawnPos[2] = 0.0;
	
    for (int i = 0; i < FORCE_SPAWN_MAX_ATTEMPTS; i++)
    {
        // 1. 检查是否超时
        if (GetEngineTime() - startTime > FORCE_SPAWN_TIMEOUT)
        {
            #if DEBUG
            PrintToServer("[AdvSpawn] [Force Spawn] Timeout reached for %s after %.2f seconds.", sClassName, GetEngineTime() - startTime);
            #endif
            break; // 超时，退出循环
        }

        //float spawnPos[3];
        bool bPosFound = false;

        // 2. 智能选点：优先从已有的候选列表中随机选点
        if (g_hSpawnCandidateList != null && g_hSpawnCandidateList.Length > 0)
        {
            int randIndex = GetRandomInt(0, g_hSpawnCandidateList.Length - 1);
            SpawnCandidate candidate;
            g_hSpawnCandidateList.GetArray(randIndex, candidate);
            spawnPos = candidate.pos;
            bPosFound = true;
        }
        // 3. 后备方案：如果候选列表为空，则动态寻找点位
        else
        {
            int leader = GetAheadSurvivor();
            if (leader == 0) leader = GetRandomSurvivorIndex();
            if (leader != 0)
            {
                // 尝试7次寻找一个随机位置
                bPosFound = L4D_GetRandomPZSpawnPosition(leader, classToSpawn, 7, spawnPos);
            }
        }

        // 4. 尝试生成
        if (bPosFound)
        {
            g_bCanSpawn = true;
            int entity = L4D2_SpawnSpecial(classToSpawn, spawnPos, NULL_VECTOR);
            g_bCanSpawn = false;

            if (entity > 0 && IsValidEntity(entity))
            {
                // 成功生成，记录日志并返回实体ID
                #if DEBUG
                PrintToServer("[AdvSpawn] [Force Spawn] Success on attempt %d: Spawned %s.", i + 1, sClassName);
                #endif
                return entity;
            }
        }
        // 如果生成失败 (bPosFound为false或entity无效)，循环将继续下一次尝试
    }

    // 循环结束仍未成功，则记录最终失败
    #if DEBUG
    PrintToServer("[AdvSpawn] [Force Spawn] All %d attempts failed for %s.", FORCE_SPAWN_MAX_ATTEMPTS, sClassName);
    #endif
    return 0; // 所有尝试均失败
}


// ====================================================================================================
// >> EVENT HANDLERS & FORWARD CALLBACKS
// ====================================================================================================


public void Event_OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    Reset(); 
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) 
{
    Reset();
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    // 如果死亡的是被本插件标记的特感，清除标记
    if (client > 0 && GetClientTeam(client) == 3 && g_bMark[client])
    {
        g_bMark[client] = false;
        g_fSpecialActionTime[client] = 0.0;
    }
}

public void OnClientPutInServer(int client)
{
    // 为 Bot 特感初始化活动时间，避免被立即清理
    if (IsFakeClient(client))
    {
        g_fSpecialActionTime[client] = GetEngineTime();
    }
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    // 如果刷特逻辑已经启动了，就什么都不做
    if (g_bSpawnLogicStarted)
    {
        return Plugin_Continue;
    }

    // 如果有 readyup 插件，但比赛还没开始 (OnRoundIsLive还没被调用)，也什么都不做
    if (g_bReadyUpExists && !g_bIsRoundLive)
    {
        return Plugin_Continue;
    }

    // 所有条件均满足，正式启动刷特逻辑
    PrintToServer("[AdvSpawn] Conditions met (Round is live AND survivor left safe area). Starting spawn logic.");
    
    g_bSpawnLogicStarted = true;

    // 创建主生成计时器，首次触发有延迟
    if (g_hMasterSpawnTimer == null)
    {
        CreateTimer(g_fFirstSpawnTime, FirstSpawn_Timer);
    }
    
    return Plugin_Continue;
}


public Action L4D_OnSpawnSpecial(int &zombieClass, const float vecPos[3], const float vecAng[3])
{
    // 如果不是本插件主动生成的，并且开启了拦截，则阻止生成
	if (!g_bCanSpawn && g_bBlockSpawn)
	{
        #if DEBUG
		char sClassName[32];
        GetZombieClassName(zombieClass, sClassName, sizeof(sClassName));
		PrintToServer("[AdvSpawn] Blocked a native %s spawn.", sClassName);
        #endif
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void L4D_OnSpawnSpecial_Post(int client, int zombieClass, const float vecPos[3], const float vecAng[3])
{
    // 任何特感生成后，都记录其初始时间
	if (client > 0)
		g_fSpecialActionTime[client] = GetEngineTime();
}

public void ConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{ 
    GetCvars(); // CVar 变化时，重新缓存所有值
}

/**
 * 这是 g_cvMaxSILimit 的变化监听回调函数
 * 当 "l4d2_si_spawn_control_max_specials" 的值发生变化时，此函数被立即调用
 */
public void OnMaxSIChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    // 检查是否成功获取了 z_max_player_zombies 的句柄
    if (g_h_zMaxPlayerZombies != null)
    {
        // 将 g_cvMaxSILimit 的新值，立即同步设置给 z_max_player_zombies
        int newLimit = convar.IntValue;
        g_h_zMaxPlayerZombies.SetInt(newLimit);
    }
}

// ====================================================================================================
// >> TIMER CALLBACKS
// ====================================================================================================

public Action FirstSpawn_Timer(Handle timer)
{
    // 首次生成后，启动常规循环计时器
    MasterSpawnTimer(null);
    if(g_hMasterSpawnTimer == null)
    {
        g_hMasterSpawnTimer = CreateTimer(g_fSpawnTime, MasterSpawnTimer, _, TIMER_REPEAT);
    }
    return Plugin_Continue;
}

/**
 * @brief 周期性计时器，用于检测并清理长时间不活动的特感
 */
public Action KillSICheck_Timer(Handle timer)
{
    if (g_fKillSITime <= 0.0) return Plugin_Continue; // 如果设置为0或更小，则禁用此功能

    for (int i = 1; i <= MaxClients; i++)
    {
        // 只检查被插件标记的特感
        if (g_bMark[i])
        {
            if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
            {
                if (GetEngineTime() - g_fSpecialActionTime[i] > g_fKillSITime)
                {
                #if DEBUG
                    PrintToServer("[AdvSpawn] Killing idle SI %N.", i);
                #endif
                    ForcePlayerSuicide(i); // 强制自杀
                    g_bMark[i] = false; // 清除标记
                }
            }
            else
            {
                // 如果玩家掉线、死亡或更换队伍，清理标记
                g_bMark[i] = false;
            }
        }
    }
    return Plugin_Continue;
}

/**
 * @brief  周期性计时器，用于解锁因生成失败而被临时禁用的特感类型
 */
public Action Timer_ClearBlockedClasses(Handle timer)
{
    for (int i = 1; i < SI_CLASS_SIZE; i++)
    {
        if (g_bClassBlocked[i] && GetEngineTime() > g_fClassBlockTime[i])
        {
            g_bClassBlocked[i] = false;
        }
    }
    return Plugin_Continue;
}

/**
 * @brief  延迟验证生成结果，用于解决 L4D2_SpawnSpecial 异步问题并提供准确日志
 */
public Action Timer_ValidateSpawn(Handle timer, DataPack pack)
{
    pack.Reset();
    int entity = pack.ReadCell();
    int requestedClass = pack.ReadCell();
    int currentCount = pack.ReadCell();
    int totalToSpawn = pack.ReadCell();
    char phase[32];
    pack.ReadString(phase, sizeof(phase));
    delete pack;

    if (IsValidEntity(entity))
    {
        int actualClass = GetEntProp(entity, Prop_Send, "m_zombieClass");
        char actualClassName[32], requestedClassName[32];
        GetZombieClassName(actualClass, actualClassName, sizeof(actualClassName));
        GetZombieClassName(requestedClass, requestedClassName, sizeof(requestedClassName));

        if (actualClass == requestedClass)
        {
            PrintToServer("[AdvSpawn] [%s] Success (%d/%d): Spawned %s.", phase, currentCount, totalToSpawn, actualClassName);
        }
        else
        {
            PrintToServer("[AdvSpawn] [%s] Success (%d/%d): Requested %s, but Director spawned %s.", phase, currentCount, totalToSpawn, requestedClassName, actualClassName);
        }
    }
    return Plugin_Continue;
}

/**
 * @brief 地图开始时延迟时钟的回调函数
 * 在地图加载1秒后执行，确保设置最终生效
 */
public Action Timer_SetMaxSpecials(Handle timer)
{
    if (g_h_zMaxPlayerZombies != null)
    {
        int limit = g_cvMaxSILimit.IntValue;
        g_h_zMaxPlayerZombies.SetInt(limit);

        // 在服务器控制台打印一条信息，方便确认操作成功
        PrintToServer("[AdvSpawn] Special infected limit synchronized to %d via map start timer.", limit);
    }
    return Plugin_Continue;
}

// ====================================================================================================
// >> SORTING FUNCTIONS
// ====================================================================================================


/**
 *  @brief  ArrayList 排序比较函数：按高度(Z轴)降序排列
 */
public int Sort_ByHeightDesc(int index1, int index2, Handle array, Handle hndl)
{
    ArrayList al = view_as<ArrayList>(array);
    SpawnCandidate cand1, cand2;
    al.GetArray(index1, cand1);
    al.GetArray(index2, cand2);

    float z1 = cand1.pos[2];
    float z2 = cand2.pos[2];

    // 降序排列：高度高的在前
    if (z1 > z2) return -1;
    if (z1 < z2) return 1;
    return 0;
}

/**
 * @brief  ArrayList 排序比较函数：随机排序
 */
public int Sort_RandomInt(int index1, int index2, Handle array, Handle hndl)
{
    return GetRandomInt(-1, 1);
}


// ====================================================================================================
// >> HELPER & UTILITY FUNCTIONS
// ====================================================================================================

/**
 * @brief  将所有 ConVar 的值读取并缓存到全局变量中
 */
void GetCvars()
{
    for (int i = 1; i < SI_CLASS_SIZE; i++) 
    {
        g_iSpecialLimit[i] = g_cvSpecialLimit[i].IntValue;
    }
    g_iMaxSILimit = g_cvMaxSILimit.IntValue;
    g_fSpawnTime = g_cvSpawnTime.FloatValue;
    g_fFirstSpawnTime = g_cvFirstSpawnTime.FloatValue;
    g_fKillSITime = g_cvKillSITime.FloatValue;
    g_bBlockSpawn = g_cvBlockSpawn.BoolValue;
    g_bHighGroundPriority = g_cvHighGroundPriority.BoolValue;
    g_fMinSpawnDist = g_cvMinSpawnDist.FloatValue;
    g_fMaxSpawnDist = g_cvMaxSpawnDist.FloatValue;
    g_fMaxFlowDiff = g_cvMaxFlowDiff.FloatValue;
    g_iNumGroups = g_cvNumGroups.IntValue;
}

/**
 * @brief  重置插件在回合/地图间的状态变量
 */
void Reset()
{
    g_bIsRoundLive  = false;
    g_bSpawnLogicStarted = false;
    g_bCanSpawn = false;
    delete g_hMasterSpawnTimer;
    g_hMasterSpawnTimer = null;
    delete g_hSpawnCandidateList;
    g_hSpawnCandidateList = null;

    for (int i = 1; i <= MaxClients; i++)
    {
        g_bMark[i] = false;
        g_fSpecialActionTime[i] = 0.0;
    }
    // 日志，便于调试地图切换问题
    PrintToServer("[AdvSpawn] Plugin state has been reset for the new round.");
}

/**
 * @brief 监听并接收来自 readyup 插件的比赛开始信号。
 * @note  这个函数名 "OnRoundIsLive" 是根据 readyup 插件源代码确定的。
 * @link  https://github.com/SirPlease/L4D2-Competitive-Rework/blob/master/addons/sourcemod/scripting/readyup/setup.inc
 */
public void OnRoundIsLive()
{
    // 如果由于某种原因 readyup 插件被卸载了，就不执行
    if (!g_bReadyUpExists)
    {
        return;
    }
    
    PrintToServer("[AdvSpawn] Signal 'OnRoundIsLive' received from Ready-Up. Waiting for survivors to leave safe area.");
    g_bIsRoundLive = true;
}


/**
 * @brief  根据当前场上特感数量和限制，随机决定下一个要生成的特感类型
 * @return 返回特感的 class ID (1-6)，如果没有可生成的则返回 0
 */
int GetSpawnClass()
{
    // 1. 统计当前每种特感的数量
    int classCount[SI_CLASS_SIZE];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
        {
            int class = GetEntProp(i, Prop_Send, "m_zombieClass");
            if (class >= 1 && class < SI_CLASS_SIZE)
            {
                classCount[class]++;
            }
        }
    }

    // 2. 构建一个允许生成的特感列表
    int availableClasses[SI_CLASS_SIZE];
    int availableCount = 0;
    // 如果该类型未达到上限，且未被临时禁用，则加入可用列表
    for (int i = 1; i < SI_CLASS_SIZE; i++)
    {
        if (classCount[i] < g_iSpecialLimit[i] && !g_bClassBlocked[i])
        {
            availableClasses[availableCount++] = i;
        }
    }

    // 3. 如果没有可生成的种类，返回0
    if (availableCount == 0)
    {
        return 0;
    }

    // 4. 从可用列表中随机选择一个
    int randomIndex = GetRandomInt(0, availableCount - 1);
    return availableClasses[randomIndex];
}


/**
 * @brief  获取当前存活的幸存者数量 (不包括倒地/挂边)
 * @return 存活幸存者数量
 */
int GetSurvivorCount()
{
    int iCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsPlayerIncapacitated(i))
        {
            iCount++;
        }
    }
    return iCount;
}

/**
 * @brief  获取当前场上所有存活特感的总数
 * @return 特感总数
 */
int GetAllSpecialsTotal()
{
    int iCount = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
        {
            iCount++;
        }
    }
    return iCount;
}

/**
 * 获取最领先的幸存者 (基于流程距离)
 * @return  领先幸存者的客户端索引，如果没有则返回0
 */
int GetAheadSurvivor()
{
    int iLeader = 0;
    float fMaxFlow = 0.0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsPlayerIncapacitated(i))
        {
            float fFlow = L4D2Direct_GetFlowDistance(i);
            if (fFlow > fMaxFlow)
            {
                fMaxFlow = fFlow;
                iLeader = i;
            }
        }
    }
    return iLeader;
}

/**
 * 随机获取一个存活的幸存者
 * @return  幸存者的客户端索引，如果没有则返回0
 */
int GetRandomSurvivorIndex()
{
    int[] survivors = new int[MaxClients];
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsPlayerIncapacitated(i))
        {
            survivors[count++] = i;
        }
    }
    if (count == 0) return 0;
    return survivors[GetRandomInt(0, count - 1)];
}

/**
 * @brief  检查导航点的生成属性是否有效
 * @param  flags        导航区域的属性标志
 * @param  bFinaleArea  当前是否为终局区域
 * @return 如果有效则返回 true
 */
bool IsValidFlags(int flags, bool bFinaleArea)
{
    // 过滤掉安全区和救援机关/车辆区域
    if (flags & (TERROR_NAV_CHECKPOINT | TERROR_NAV_RESCUE_CLOSET | TERROR_NAV_RESCUE_VEHICLE))
    {
        return false;
    }

    // 如果是终局地图，导航点必须有 FINALE 标志
    if (bFinaleArea && (flags & TERROR_NAV_FINALE) == 0)
    {
        return false;
    }

    return true;
}

/**
 * @brief  检查一个位置是否会卡住实体 (例如在墙里)
 * @param  pos 坐标
 * @return 如果会卡住则返回 true
 */
bool WillStuck(float pos[3])
{
    float mins[3] = {-16.0, -16.0, 0.0};
    float maxs[3] = {16.0, 16.0, 72.0};

    Handle trace = TR_TraceHullFilterEx(pos, pos, mins, maxs, MASK_PLAYERSOLID, TraceFilter_IgnorePlayers);
    bool stuck = TR_DidHit(trace);
    delete trace;
    return stuck;
}

/**
 * @brief  执行精确的多点视野检查，模拟特感的脚部、躯干和头部，以杜绝当面刷新。
 * @brief  只要三个检测点中的任意一个对幸存者可见，该位置即被视为“可见”。
 * @param  targetPos 要检查的目标位置 (通常是导航网格的地面坐标)
 * @param  client    幸存者客户端索引
 * @return 如果幸存者的视线能无障碍地看到目标点站立的特感的任何关键部位，则返回 true；否则返回 false。
 */
bool IsPositionVisibleToClient(const float targetPos[3], int client)
{
    // 1. 获取幸存者的眼睛位置
    float clientEyePos[3];
    GetClientEyePosition(client, clientEyePos);

    // 2. 定义需要检测的三个点的Z轴高度偏移量
    // 分别代表：头部 (72.0), 躯干 (60.0), 脚部 (10.0)
    float z_offsets[3] = { 72.0, 60.0, 10.0 };

    // 3. 遍历这三个点，进行射线检测
    for (int i = 0; i < 3; i++)
    {
        // 为当前检测点计算带有高度补偿的坐标
        float compensatedTargetPos[3];
        compensatedTargetPos = targetPos; // 从地面坐标开始
        compensatedTargetPos[2] += z_offsets[i]; // 加上当前点的高度偏移

        // 从幸存者眼睛向这个补偿点发射射线
        Handle trace = TR_TraceRayFilterEx(clientEyePos, compensatedTargetPos, MASK_SOLID_BRUSHONLY, RayType_EndPoint, TraceFilter_IgnorePlayers);

        // 4. 检查射线是否击中障碍物
        // 如果 TR_DidHit() 返回 false，意味着射线没有击中任何东西，视线是通畅的
        if (!TR_DidHit(trace))
        {
            // 只要有一个点可见，就立即判定整个位置为“可见”
            // 无需再检查其他点，直接返回 true 并清理句柄
            delete trace;
            return true; 
        }

        // 如果射线被阻挡，清理句柄，然后继续循环，检查下一个点
        delete trace;
    }

    // 5. 如果循环结束后，三个点都被证明是不可见的（都被障碍物阻挡）
    // 那么这个位置就是安全的，返回 false
    return false;
}

/**
 * 根据特感类别ID获取其名称字符串
 * @param class     特感类别ID
 * @return          特感名称
 */
void GetZombieClassName(int zombieClass, char[] buffer, int maxlen) {
    switch(zombieClass) {
        case 1: {strcopy(buffer, maxlen, "Smoker");}
        case 2: {strcopy(buffer, maxlen, "Boomer");}
        case 3: {strcopy(buffer, maxlen, "Hunter");}
        case 4: {strcopy(buffer, maxlen, "Spitter");}
        case 5: {strcopy(buffer, maxlen, "Jockey");}
        case 6: {strcopy(buffer, maxlen, "Charger");}
        case 7: {strcopy(buffer, maxlen, "Witch");}
        case 8: {strcopy(buffer, maxlen, "Tank");}
        default: {strcopy(buffer, maxlen, "Unknown");}
    }
}

/**
 * @brief  辅助函数：记录生成日志，避免代码重复
 */
void LogSpawn(int entity, int requestedClass, float height, int currentCount, int totalToSpawn, const char[] phase)
{
#if DEBUG
    char actualClassName[32], requestedClassName[32];
    int actualClass = IsValidEntity(entity) ? GetEntProp(entity, Prop_Send, "m_zombieClass") : 0;
    
    GetZombieClassName(requestedClass, requestedClassName, sizeof(requestedClassName));

    if (actualClass != 0)
    {
        GetZombieClassName(actualClass, actualClassName, sizeof(actualClassName));
        if (actualClass == requestedClass)
        {
            PrintToServer("[AdvSpawn] [%s | %d/%d] Spawned %s at height %.0f.", phase, currentCount, totalToSpawn, actualClassName, height);
        }
        else
        {
            // 这种情况很少见，但可能发生（导演系统覆盖）
            PrintToServer("[AdvSpawn] [%s | %d/%d] WARNING: Requested %s, but Director spawned %s at height %.0f.", phase, currentCount, totalToSpawn, requestedClassName, actualClassName, height);
        }
    }
    else
    {
        PrintToServer("[AdvSpawn] [%s | %d/%d] FAILED to spawn %s.", phase, currentCount, totalToSpawn, requestedClassName);
    }
#endif
}

/**
* @brief  创建一个包含生成信息的数据包，用于计时器传递
*/
stock DataPack CreateDataPackFromSpawnInfo(int entity, int requestedClass, int currentCount, int totalToSpawn, const char[] phase)
{
    DataPack pack = new DataPack();
    pack.WriteCell(entity);
    pack.WriteCell(requestedClass);
    pack.WriteCell(currentCount);
    pack.WriteCell(totalToSpawn);
    pack.WriteString(phase);
    return pack;
}

/**
 * @brief  获取所有存活且未倒地的幸存者
 * @param  survivors 用于接收幸存者索引的数组
 * @return 存活幸存者的数量
 */
stock int GetAliveSurvivors(int survivors[MAXPLAYERS+1])
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsPlayerIncapacitated(i))
        {
            survivors[count++] = i;
        }
    }
    return count;
}

/**
 * @brief  判断玩家是否倒地或挂边
 */
stock bool IsPlayerIncapacitated(int client)
{
    return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

/**
 * @brief  判断向量是否为零
 */
stock bool IsVectorZero(const float vec[3])
{
    return vec[0] == 0.0 && vec[1] == 0.0 && vec[2] == 0.0;
}

/**
 * @brief  射线检测过滤器：忽略所有玩家
 */
public bool TraceFilter_IgnorePlayers(int entity, int contentsMask)
{
    return !(entity > 0 && entity <= MaxClients); 
}
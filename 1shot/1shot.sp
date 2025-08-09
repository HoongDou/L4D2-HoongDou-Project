#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "4.3.4"
#define DEBUG 1
#define SHOTGUN_DAMAGE_WINDOW 0.15
#define MAX_ATTACKERS 32
#define MAXENTITIES 2048

// 全局变量
//插件默认关闭，如需插件默认开启可改为true
bool g_bOneShotEnabled = false;
ConVar g_hCvarAirshotMultiplier;
ConVar g_hCvarGroundMultiplier;

// 霰弹枪伤害累积系统
//记录每个生还者对每个特感最后一次造成霰弹枪伤害的游戏时间
float g_fLastShotgunDamage[MAXPLAYERS + 1][MAXENTITIES];
//记录每个生还者对每个特感在时间窗口内累积的霰弹枪伤害
float g_fAccumulatedDamage[MAXPLAYERS + 1][MAXENTITIES];
// 记录造成累积伤害的武器实体索引，防止不同武器的伤害混淆
int g_iAccumulatedWeapon[MAXPLAYERS + 1][MAXENTITIES];
// 用于处理累积伤害的定时器句柄
Handle g_hDamageTimer[MAXPLAYERS + 1][MAXENTITIES];

// 非霰弹枪伤害冷却系统
float g_fLastDamageTime[MAXENTITIES];
float g_fLastDamageAmount[MAXENTITIES];
int g_iLastDamageAttacker[MAXENTITIES];

// 特感类名（本次处理不含Tank和Witch）
static const char g_sSIClassnames[][] = {
    "smoker",
    "boomer",
    "hunter",
    "spitter",
    "jockey",
    "charger"
};

// 霰弹枪类名
static const char g_sShotgunClassnames[][] = {
    "weapon_pumpshotgun",
    "weapon_shotgun_chrome",
    "weapon_autoshotgun",
    "weapon_shotgun_spas"
};

public Plugin myinfo = 
{
    name = "[L4D2]1 Shot Mode",
    author = "HoongDou ",
    description = "特感只有在单次受到超过其最大生命值的伤害时才会死亡，否则将回满血。支持空中/地面倍率伤害",
    version = PLUGIN_VERSION,
    url = "https://github.com/HoongDou"
};

// ==========================================================================================
// --- 插件主回调函数 (Plugin Callbacks) ---
// ==========================================================================================

/**
 * @brief 插件启动时调用，用于初始化所有内容。
 */
public void OnPluginStart()
{
    CreateConVar("l4d2_1shotkill_version", PLUGIN_VERSION, "1 Shot Mode Plugin Version", FCVAR_NOTIFY | FCVAR_SPONLY | FCVAR_DONTRECORD);
    
    RegConsoleCmd("sm_oneshot", Command_ToggleOneShot, "开启或关闭秒杀模式");
    RegConsoleCmd("sm_os", Command_ToggleOneShot, "开启或关闭秒杀模式");
    
    g_hCvarAirshotMultiplier = CreateConVar("sm_airshot_multiplier", "1.0", "对空中特感的伤害倍率", FCVAR_NOTIFY, true, 0.1);
    g_hCvarGroundMultiplier = CreateConVar("sm_ground_multiplier", "1.0", "对地面特感的伤害倍率", FCVAR_NOTIFY, true, 0.1);
    
    // 注册SDKHooks
    HookEvent("player_spawn", Event_PlayerSpawn);
    
    // Hook所有现有实体
    HookExistingSpecials();
    
    // 初始化伤害系统
    ResetAllDamageSystems();
    
    #if DEBUG
    RegConsoleCmd("sm_debug_dmg", Command_DebugDamage, "调试伤害系统");
    #endif
}

/**
 * @brief 地图开始时调用，用于重置状态。
 */
public void OnMapStart()
{
    PrecacheSound("ui/littlereward.wav", true);
    HookExistingSpecials();
    ResetAllDamageSystems();
}

/**
 * @brief 当游戏创建新实体时调用。
 * @param entity        新创建的实体索引。
 * @param classname     新创建的实体的类名。
 */
public void OnEntityCreated(int entity, const char[] classname)
{
    if (IsValidEntity(entity) && IsSpecialInfectedClass(classname)) {
        SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
        ResetEntityDamage(entity);
    }
}

/**
 * @brief 当游戏销毁实体时调用。
 * @param entity        被销毁的实体索引。
 */
public void OnEntityDestroyed(int entity)
{
    if (entity > 0 && entity < MAXENTITIES) {
        ResetVictimDamageSystems(entity);
    }
}

/**
 * @brief 当客户端（玩家）断开连接时调用。
 * @param client        断开连接的客户端索引。
 */
public void OnClientDisconnect(int client)
{
    if (client > 0 && client <= MaxClients) {
        ResetAttackerDamageSystems(client);
    }
}

/**
 * @brief 玩家出生时触发（包括回合开始或复活）。
 * @param event         事件句柄。
 * @param name          事件名。
 * @param dontBroadcast 是否广播。
 */
public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == 3) {
        SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    }
}

// ==========================================================================================
// --- 核心伤害处理 (Core Damage Logic) ---
// ==========================================================================================

/**
 * @brief 核心函数，通过SDKHook在实体受到伤害时触发。
 * @brief 这是所有伤害逻辑的入口点。
 * @param victim        受害者实体索引。
 * @param attacker      攻击者实体索引（客户端索引）。
 * @param inflictor     造成伤害的实体（如手雷、爆炸桶）。
 * @param damage        伤害值。
 * @param damagetype    伤害类型。
 * @param weapon        武器实体索引。
 * @return              返回Plugin_Continue以允许伤害，Plugin_Changed来修改伤害，Plugin_Handled来阻止伤害。
 */
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (!g_bOneShotEnabled || damage <= 0.0) {
        return Plugin_Continue;
    }
    
    // 验证攻击者（生还）
    if (!IsValidAttacker(attacker)) {
        return Plugin_Continue;
    }
    
    // 验证受害者（特感）
    bool isPlayer = (victim >= 1 && victim <= MaxClients);
    if (isPlayer) {
        if (!IsClientInGame(victim) || GetClientTeam(victim) != 3 || !IsValidSIClient(victim)) {
            return Plugin_Continue;
        }
    } else {
        if (!IsValidEntity(victim) || !IsSpecialInfectedEntity(victim)) {
            return Plugin_Continue;
        }
    }
    
    // 检查武器是否为霰弹枪
    char weaponClassname[32];
    bool isShotgun = false;
    if (IsValidEntity(weapon)) {
        GetEntityClassname(weapon, weaponClassname, sizeof(weaponClassname));
        for (int i = 0; i < sizeof(g_sShotgunClassnames); i++) {
            if (StrEqual(weaponClassname, g_sShotgunClassnames[i])) {
                isShotgun = true;
                break;
            }
        }
    }
    
    // 霰弹枪伤害累积系统（按攻击者-受害者组合）
    if (isShotgun) {
        float currentTime = GetGameTime();
        
        // 检查是否在同一个霰弹枪射击窗口内(0.15s)，且霰弹枪为同一把
        if (currentTime - g_fLastShotgunDamage[attacker][victim] <= SHOTGUN_DAMAGE_WINDOW && 
            weapon == g_iAccumulatedWeapon[attacker][victim]) {
            
            // 累积伤害
            g_fAccumulatedDamage[attacker][victim] += damage;
            
            #if DEBUG
            PrintToServer("霰弹枪伤害累积: 攻击者 %d -> 受害者 %d, 新增伤害: %.1f, 总伤害: %.1f", 
                         attacker, victim, damage, g_fAccumulatedDamage[attacker][victim]);
            #endif
            
            // 重置计时器，等待后续弹丸
            delete g_hDamageTimer[attacker][victim];
            g_hDamageTimer[attacker][victim] = CreateTimer(SHOTGUN_DAMAGE_WINDOW, 
                Timer_ProcessShotgunDamage, 
                CreatePackCell(attacker, victim), 
                TIMER_FLAG_NO_MAPCHANGE);
            
            // 阻止本次单个弹丸的伤害，等待累积完成后再统一处理
            damage = 0.0;
            return Plugin_Changed;
        } else {
            // 新的霰弹枪射击序列
            g_fAccumulatedDamage[attacker][victim] = damage;
            g_iAccumulatedWeapon[attacker][victim] = weapon;
            g_fLastShotgunDamage[attacker][victim] = currentTime;
            
            #if DEBUG
            PrintToServer("新的霰弹枪射击序列: 攻击者 %d -> 受害者 %d, 初始伤害: %.1f", attacker, victim, damage);
            #endif
            
            // 启动计时器处理累积伤害
            delete g_hDamageTimer[attacker][victim];
            g_hDamageTimer[attacker][victim] = CreateTimer(SHOTGUN_DAMAGE_WINDOW, 
                Timer_ProcessShotgunDamage, 
                CreatePackCell(attacker, victim), 
                TIMER_FLAG_NO_MAPCHANGE);
            
            // 阻止本次伤害
            damage = 0.0;
            return Plugin_Changed;
        }
    }
    
    // 非霰弹枪武器 - 应用伤害冷却系统，过滤高射速武器在同一游戏帧内可能产生的重复伤害事件。
    float currentTime = GetGameTime();
    if (currentTime - g_fLastDamageTime[victim] < 0.15 && 
        attacker == g_iLastDamageAttacker[victim] &&
        damage == g_fLastDamageAmount[victim]) {
        #if DEBUG
        PrintToServer("忽略重复伤害事件: 受害者: %d, 伤害: %.1f", victim, damage);
        #endif
        return Plugin_Continue;
    }
    
    // 更新伤害记录
    g_fLastDamageTime[victim] = currentTime;
    g_fLastDamageAmount[victim] = damage;
    g_iLastDamageAttacker[victim] = attacker;
    
    // 处理非霰弹枪伤害
    return ProcessDamage(victim, attacker, weapon, damage);
}

/**
 * @brief 最终伤害处理函数，计算倍率并执行秒杀或回血逻辑。
 * @param victim        受害者实体索引。
 * @param attacker      攻击者客户端索引。
 * @param weapon        武器实体索引。
 * @param damage        最终伤害值（对于霰弹枪是累积后的总伤害）。
 * @return              返回Plugin_Changed以应用修改（例如回血）。
 */
Action ProcessDamage(int victim, int attacker, int weapon, float damage)
{
    // 获取原始伤害（包含爆头倍率）
    float originalDamage = damage;
    
    // 应用空中/地面倍率
    float multiplier = (GetEntityFlags(victim) & FL_ONGROUND) ? 
        g_hCvarGroundMultiplier.FloatValue : 
        g_hCvarAirshotMultiplier.FloatValue;
    
    float effectiveDamage = damage * multiplier;
    
    // 获取最大生命值
    int maxHealth = GetEntProp(victim, Prop_Data, "m_iMaxHealth");
    if (maxHealth <= 0) {
        return Plugin_Continue;// 获取不到血量则不处理
    }
    
    #if DEBUG
    char weaponName[32] = "Unknown";//对应推击(Shove)击杀
    if (IsValidEntity(weapon)) {
        GetEntityClassname(weapon, weaponName, sizeof(weaponName));
    }
    
    PrintToServer("伤害处理: 受害者: %d, 武器: %s, 原始伤害: %.1f, 倍率: %.1f, 有效伤害: %.1f, 最大生命: %d",
                 victim, weaponName, originalDamage, multiplier, effectiveDamage, maxHealth);
    #endif
    
    // 处理秒杀逻辑
    if (effectiveDamage >= maxHealth) {
        // 秒杀成功：虽然特感已经死亡，但还是通过SDKHooks施加一个超高伤害来确保特感被击杀
        SDKHooks_TakeDamage(victim, 0, attacker, 10000.0);
        CreateTimer(0.1, Timer_PlaySound, GetClientUserId(attacker), TIMER_FLAG_NO_MAPCHANGE);
        
        DataPack pack = new DataPack();
        pack.WriteCell(victim);
        pack.WriteCell(attacker);
        pack.WriteCell(RoundFloat(effectiveDamage));
        pack.WriteCell(RoundFloat(originalDamage));
        pack.WriteFloat(multiplier);
        pack.WriteCell(true);
        pack.WriteCell(maxHealth);
        
        CreateTimer(0.1, Timer_PrintKillMessage, pack, TIMER_FLAG_NO_MAPCHANGE);
    } else {
        // 伤害不足，给特感回满血
        SetEntProp(victim, Prop_Data, "m_iHealth", maxHealth);
        
		// 用计时器延迟发送聊天信息确保状态更新后再显示
        DataPack pack = new DataPack();
        pack.WriteCell(victim);
        pack.WriteCell(attacker);
        pack.WriteCell(RoundFloat(effectiveDamage));
        pack.WriteCell(RoundFloat(originalDamage));
        pack.WriteFloat(multiplier);
        pack.WriteCell(false);
        pack.WriteCell(maxHealth);
        
        CreateTimer(0.1, Timer_PrintKillMessage, pack, TIMER_FLAG_NO_MAPCHANGE);
    }
    
    return Plugin_Changed;
}

// ==========================================================================================
// --- 定时器回调 (Timer Callbacks) ---
// ==========================================================================================

/**
 * @brief 霰弹枪伤害累积窗口结束时触发。
 * @param timer         定时器句柄。
 * @param pack          包含攻击者和受害者信息的数据包。
 * @return              Plugin_Stop停止定时器。
 */
public Action Timer_ProcessShotgunDamage(Handle timer, int pack)
{
    int attacker, victim;
    UnpackPackCell(pack, attacker, victim);
    
    g_hDamageTimer[attacker][victim] = null;
	
    //安全检查
    if (!IsValidEntity(victim) || !IsSpecialInfected(victim)) {
        return Plugin_Stop;
    }
    
    if (!IsValidAttacker(attacker)) {
        return Plugin_Stop;
    }
    
    float accumulatedDamage = g_fAccumulatedDamage[attacker][victim];
    if (accumulatedDamage <= 0.0) {
        return Plugin_Stop;
    }
    
    #if DEBUG
    PrintToServer("处理霰弹枪累积伤害: 攻击者 %d -> 受害者 %d, 总伤害: %.1f", attacker, victim, accumulatedDamage);
    #endif
    
    // 处理累积伤害
    ProcessDamage(victim, attacker, g_iAccumulatedWeapon[attacker][victim], accumulatedDamage);
    
    // 重置累积器
    g_fAccumulatedDamage[attacker][victim] = 0.0;
    g_iAccumulatedWeapon[attacker][victim] = -1;
    g_fLastShotgunDamage[attacker][victim] = 0.0;
    
    return Plugin_Stop;
}

/**
 * @brief 播放击杀奖励音效的定时器。
 * @param timer         定时器句柄。
 * @param userid        攻击者的UserID。
 */
public Action Timer_PlaySound(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client > 0 && IsClientInGame(client)) {
        EmitSoundToClient(client, "ui/littlereward.wav");
    }
    return Plugin_Stop;
}

/**
 * @brief 打印伤害/击杀信息的定时器。
 * @param timer         定时器句柄。
 * @param pack          包含所有打印信息所需的数据包。
 */
public Action Timer_PrintKillMessage(Handle timer, DataPack pack)
{
    pack.Reset();
    int victim = pack.ReadCell();
    int attacker = pack.ReadCell();
    int effectiveDamage = pack.ReadCell();
    int originalDamage = pack.ReadCell();
    float multiplier = pack.ReadFloat();
    bool killed = pack.ReadCell();
    int maxHealth = pack.ReadCell();
    delete pack;
    
    if (attacker <= 0 || !IsClientInGame(attacker)) {
        return Plugin_Stop;
    }
    
    PrintKillMessage(attacker, victim, effectiveDamage, originalDamage, multiplier, killed, maxHealth);
    return Plugin_Stop;
}

// ==========================================================================================
// --- 辅助与工具函数 (Helpers & Utilities) ---
// ==========================================================================================

/**
 * @brief Hook地图上所有已经存在的特感实体。
 * @brief 在插件加载和新地图开始时调用。
 */
void HookExistingSpecials()
{
    // Hook玩家特感
    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsValidSIClient(i)) {
            SDKHook(i, SDKHook_OnTakeDamage, OnTakeDamage);
        }
    }
    
    // Hook AI特感
    for (int i = 0; i < sizeof(g_sSIClassnames); i++) {
        int entity = -1;
        while ((entity = FindEntityByClassname(entity, g_sSIClassnames[i])) != -1) {
            if (IsValidEntity(entity)) {
                SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
            }
        }
    }
}

/**
 * @brief 处理 sm_oneshot 和 sm_os ，用于开启或关闭插件。
 * @param client        执行命令的客户端索引（0代表服务器控制台）。
 * @param args          命令参数的数量（此函数中未使用）。
 * @return              返回 Plugin_Handled 来表示该action已被成功处理。
 */
public Action Command_ToggleOneShot(int client, int args)
{
    g_bOneShotEnabled = !g_bOneShotEnabled;
    if (g_bOneShotEnabled) {
        PrintToChatAll("\x04[!]\x01 1-Shot模式已\x02开启");
    } else {
        PrintToChatAll("\x04[!]\x01 1-Shot模式已\x07关闭");
    }
    return Plugin_Handled;
}


/**
 * @brief 将两个整数（攻击者和受害者索引）打包到一个32位整数中。
 * @details 通过位操作将 `attacker` 的索引左移16位，使其占据整数的高16位；
 *          同时将 `victim` 的索引保留在低16位。最后通过“或”操作将两者合并。
 * @param attacker      攻击者索引，将被存入高16位。
 * @param victim        受害者索引，将被存入低16位。
 * @return              一个包含了两个索引信息的32位整数。
 */
int CreatePackCell(int attacker, int victim)
{
    // attacker << 16: 将 attacker 的二进制位向左移动16位。
    // victim & 0xFFFF: 确保 victim 的值只在低16位内，防止溢出。
    // |: 将移动后的 attacker 和 victim 合并在一起。
    return (attacker << 16) | (victim & 0xFFFF);
}


/**
 * @brief 从一个打包的32位整数中解包出原始的两个整数（攻击者和受害者）。
 * @details 为 CreatePackCell 的逆操作。
 * @param pack          由 CreatePackCell 创建的打包整数。
 * @param attacker      用于接收解包出的攻击者索引的变量（引用传递）。
 * @param victim        用于接收解包出的受害者索引的变量（引用传递）。
 */
void UnpackPackCell(int pack, int &attacker, int &victim)
{
    // pack >> 16: 将打包整数向右移动16位，高16位的数据就移动到了低16位，从而得到原始的 attacker。
    // pack & 0xFFFF: 使用掩码 0xFFFF (二进制的16个1) 取出低16位的数据，从而得到原始的 victim。
    attacker = pack >> 16;
    victim = pack & 0xFFFF;
}




/**
 * @brief 重置所有伤害记录系统。
 */
void ResetAllDamageSystems()
{
    // 重置霰弹枪累积系统
    for (int attacker = 1; attacker <= MaxClients; attacker++) {
        for (int victim = 0; victim < MAXENTITIES; victim++) {
            ResetDamageAccumulator(attacker, victim);
        }
    }
    
    // 重置非霰弹枪冷却系统
    for (int victim = 0; victim < MAXENTITIES; victim++) {
        ResetEntityDamage(victim);
    }
}

/**
 * @brief 重置指定攻击者的所有伤害记录。
 * @param attacker      攻击者客户端索引。
 */
void ResetAttackerDamageSystems(int attacker)
{
    if (attacker < 1 || attacker > MaxClients) return;
    
    // 重置霰弹枪累积系统
    for (int victim = 0; victim < MAXENTITIES; victim++) {
        ResetDamageAccumulator(attacker, victim);
    }
}

/**
 * @brief 重置指定受害者的所有伤害记录。
 * @param victim        受害者实体索引。
 */
void ResetVictimDamageSystems(int victim)
{
    if (victim < 0 || victim >= MAXENTITIES) return;
    
    // 重置霰弹枪累积系统
    for (int attacker = 1; attacker <= MaxClients; attacker++) {
        ResetDamageAccumulator(attacker, victim);
    }
    
    // 重置非霰弹枪冷却系统
    ResetEntityDamage(victim);
}

/**
 * @brief 重置一个特定的“攻击者-受害者”组合的霰弹枪伤害累积器。
 * @param attacker      攻击者客户端索引。
 * @param victim        受害者实体索引。
 */
void ResetDamageAccumulator(int attacker, int victim)
{
    if (attacker < 1 || attacker > MaxClients) return;
    if (victim < 0 || victim >= MAXENTITIES) return;
    
    g_fAccumulatedDamage[attacker][victim] = 0.0;
    g_iAccumulatedWeapon[attacker][victim] = -1;
    g_fLastShotgunDamage[attacker][victim] = 0.0;
    delete g_hDamageTimer[attacker][victim];
}

/**
 * @brief 重置一个特定实体的非霰弹枪伤害冷却记录。
 * @param entity        实体索引。
 */
void ResetEntityDamage(int entity)
{
    if (entity < 0 || entity >= MAXENTITIES) return;
    
    g_fLastDamageTime[entity] = 0.0;
    g_fLastDamageAmount[entity] = 0.0;
    g_iLastDamageAttacker[entity] = 0;
}



// ==========================================================================================
// --- 验证与检查函数 (Validation & Check Functions) ---
// ==========================================================================================

/**
 * @brief 检查一个实体是否为我们想要处理的特感（玩家或AI）。
 * @param entity        实体索引。
 * @return              如果是，返回true。
 */
bool IsSpecialInfected(int entity)
{
    // 如果实体索引在客户端范围内，则按客户端逻辑检查
    if (entity >= 1 && entity <= MaxClients) {
        return IsValidSIClient(entity);
    }
	// 否则按普通实体逻辑检查
    return IsSpecialInfectedEntity(entity);
}

/**
 * @brief 检查攻击者是否为有效的生还者玩家。
 * @param attacker      攻击者客户端索引。
 * @return              如果是，返回true。
 */
bool IsValidAttacker(int attacker)
{
    return (attacker > 0 && 
            attacker <= MaxClients && 
            IsClientInGame(attacker) && 
            GetClientTeam(attacker) == 2);
}

/**
 * @brief 检查一个客户端是否为有效的特感玩家（排除Tank）。
 * @param client        客户端索引。
 * @return              如果是，返回true。
 */
bool IsValidSIClient(int client)
{
    if (client <= 0 || !IsClientInGame(client)) return false;
    if (GetClientTeam(client) != 3) return false;
    
    // 通过m_zombieClass属性判断，1-6为普通特感，8为Tank
    int zClass = GetEntProp(client, Prop_Send, "m_zombieClass");
    return (zClass >= 1 && zClass <= 6); // 1-6为特感
}

/**
 * @brief 检查一个实体是否为AI控制的特感。
 * @param entity        实体索引。
 * @return              如果是，返回true。
 */
bool IsSpecialInfectedEntity(int entity)
{
    if (!IsValidEntity(entity)) return false;
    
    char classname[32];
    GetEntityClassname(entity, classname, sizeof(classname));
    
    for (int i = 0; i < sizeof(g_sSIClassnames); i++) {
        if (StrEqual(classname, g_sSIClassnames[i])) {
            return true;
        }
    }
    return false;
}

/**
 * @brief 检查一个类名是否属于特感。
 * @param classname     实体的类名字符串。
 * @return              如果是，返回true。
 */
bool IsSpecialInfectedClass(const char[] classname)
{
    for (int i = 0; i < sizeof(g_sSIClassnames); i++) {
        if (StrEqual(classname, g_sSIClassnames[i])) {
            return true;
        }
    }
    return false;
}

// ==========================================================================================
// --- 输出与格式化函数 (Output & Formatting Functions) ---
// ==========================================================================================

/**
 * @brief 向攻击者打印格式化的击杀/伤害信息。
 * @param attacker      攻击者客户端索引。
 * @param victim        受害者实体索引。
 * @param effectiveDmg  计算倍率后的有效伤害。
 * @param rawDmg        原始伤害。
 * @param multi         伤害倍率。
 * @param killed        是否击杀。
 * @param threshold     秒杀所需的血量阈值。
 */
void PrintKillMessage(int attacker, int victim, int effectiveDmg, int rawDmg, float multi, bool killed, int threshold = 0)
{
    char victimName[64];
    // 判断受害者是玩家还是AI，并获取其名字
    if (victim >= 1 && victim <= MaxClients && IsClientInGame(victim)) {
        GetClientName(victim, victimName, sizeof(victimName));
    } else {
        char clsName[32];
        GetEntityClassname(victim, clsName, sizeof(clsName));
        clsName[0] = CharToUpper(clsName[0]); // 首字母大写
        Format(victimName, sizeof(victimName), "%s", clsName);
    }
    
    if (killed) {
        PrintToChat(attacker, "\x04[!]\x01 你对 \x05%s\x01 造成了 \x02%d \x01(原始: %d x%.1f) 点伤害，\x05秒杀成功!", 
                   victimName, effectiveDmg, rawDmg, multi);
    } else {
        PrintToChat(attacker, "\x04[!]\x01 你对 \x05%s\x01 造成了 \x07%d \x01(原始: %d x%.1f) 点伤害, 未达到 \x02%d\x01 点秒杀阈值。", 
                   victimName, effectiveDmg, rawDmg, multi, threshold);
    }
}
// ==========================================================================================
// --- 调试 (Debugging) ---
// ==========================================================================================

#if DEBUG

/**
 * @brief 调试命令，用于显示当前伤害系统状态。
 * @param client        执行命令的客户端索引。
 * @param args          命令参数个数。
 */
public Action Command_DebugDamage(int client, int args)
{
    if (client == 0) {
        PrintToServer("该命令只能在游戏中使用");
        return Plugin_Handled;
    }
    
    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    char weaponName[32] = "None";
    if (IsValidEntity(weapon)) {
        GetEntityClassname(weapon, weaponName, sizeof(weaponName));
    }
    
    PrintToChat(client, "当前武器: %s", weaponName);
    PrintToChat(client, "伤害倍率: 地面 %.1f, 空中 %.1f", 
        g_hCvarGroundMultiplier.FloatValue,
        g_hCvarAirshotMultiplier.FloatValue);
    
    // 检查当前瞄准的实体
    int target = GetClientAimTarget(client, true);
    if (target > 0) {
        char clsName[32];
        GetEntityClassname(target, clsName, sizeof(clsName));
        int health = GetEntProp(target, Prop_Data, "m_iHealth");
        int maxHealth = GetEntProp(target, Prop_Data, "m_iMaxHealth");
        
        PrintToChat(client, "目标实体: %s (%d)", clsName, target);
        PrintToChat(client, "血量: %d/%d", health, maxHealth);
        PrintToChat(client, "是否在空中: %s", (GetEntityFlags(target) & FL_ONGROUND) ? "否" : "是");
        
        // 显示霰弹枪累积伤害
        PrintToChat(client, "霰弹枪累积伤害:");
        bool found = false;
        for (int i = 1; i <= MaxClients; i++) {
            if (g_fAccumulatedDamage[i][target] > 0) {
                found = true;
                char attackerName[32];
                if (IsClientInGame(i)) GetClientName(i, attackerName, sizeof(attackerName));
                else Format(attackerName, sizeof(attackerName), "攻击者 %d", i);
                
                PrintToChat(client, "-> %s: %.1f 伤害", attackerName, g_fAccumulatedDamage[i][target]);
            }
        }
        if (!found) {
            PrintToChat(client, "-> 无");
        }
        
        // 显示非霰弹枪冷却信息
        if (g_fLastDamageTime[target] > 0) {
            char lastAttackerName[32];
            int lastAttacker = g_iLastDamageAttacker[target];
            if (lastAttacker > 0 && IsClientInGame(lastAttacker)) {
                GetClientName(lastAttacker, lastAttackerName, sizeof(lastAttackerName));
            } else {
                Format(lastAttackerName, sizeof(lastAttackerName), "攻击者 %d", lastAttacker);
            }
            
            PrintToChat(client, "最后非霰弹伤害: %.1f秒前, 伤害量: %.1f, 攻击者: %s",
                GetGameTime() - g_fLastDamageTime[target],
                g_fLastDamageAmount[target],
                lastAttackerName);
        }
    }
    
    return Plugin_Handled;
}
#endif
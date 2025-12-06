#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION "2.3.0"
#define GAMEDATA_FILE "M60_GrenadeLauncher_patches"

// ConVars
ConVar g_cvClipSize;
ConVar g_cvReserveAmmo;

// 内存补丁变量
Address g_addrM60Drop = Address_Null;
int g_iM60DropRestore;
Address g_addrAmmoUse = Address_Null;
int g_iAmmoUseRestore;

// 数据持久化
int g_iDroppedReserve[2049];  // 掉落时的备弹记录，-1表示新枪
int g_iDroppedClip[2049];     // 掉落时的弹匣记录

// 换弹状态追踪
bool g_bIsReloading[MAXPLAYERS + 1];
int g_iReloadingWeapon[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "[L4D2] Modern M60",
    author = "Lux & MasterMind420 & HoongDou",
    description = "Fixes M60 drop, reloading, and ammo persistence.",
    version = PLUGIN_VERSION,
    url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(error, err_max, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }
    return APLRes_Success;
}

public void OnPluginStart()
{
    Handle hGamedata = LoadGameConfigFile(GAMEDATA_FILE);
    if (hGamedata == null)
        SetFailState("Failed to load \"%s.txt\".", GAMEDATA_FILE);

    Patch_M60_Drop(hGamedata);
    Patch_M60_Ammo(hGamedata);
    delete hGamedata;

    g_cvClipSize = CreateConVar("l4d2_m60_clip", "150", "M60 Clip Size", FCVAR_NOTIFY);
    g_cvReserveAmmo = CreateConVar("l4d2_m60_reserve", "300", "M60 Reserve Ammo", FCVAR_NOTIFY);

    //AutoExecConfig(true, "l4d2_m60_modern_fix");

    HookEvent("weapon_reload", Event_WeaponReload);
    HookEvent("player_spawn", Event_PlayerSpawn);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i)) OnClientPutInServer(i);
    }
}

public void OnMapStart()
{
    for (int i = 0; i < sizeof(g_iDroppedReserve); i++)
    {
        g_iDroppedReserve[i] = -1;
        g_iDroppedClip[i] = -1;
    }
    
    for (int i = 1; i <= MaxClients; i++)
    {
        g_bIsReloading[i] = false;
        g_iReloadingWeapon[i] = -1;
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
    SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
    g_bIsReloading[client] = false;
    g_iReloadingWeapon[client] = -1;
}

public void OnClientDisconnect(int client)
{
    g_bIsReloading[client] = false;
    g_iReloadingWeapon[client] = -1;
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client > 0)
    {
        g_bIsReloading[client] = false;
        g_iReloadingWeapon[client] = -1;
    }
}

// ==================================================================================================
// 实体生命周期
// ==================================================================================================

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity > 0 && entity < sizeof(g_iDroppedReserve))
    {
        g_iDroppedReserve[entity] = -1;
        g_iDroppedClip[entity] = -1;
    }
    
    // Hook弹药堆
    if (StrEqual(classname, "weapon_ammo_spawn"))
    {
        SDKHook(entity, SDKHook_Use, OnAmmoUse);
    }
}

// ==================================================================================================
// 武器丢弃时保存弹药数据
// ==================================================================================================

public Action OnWeaponDrop(int client, int weapon)
{
    if (!IsValidEntity(weapon)) return Plugin_Continue;

    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (StrEqual(classname, "weapon_rifle_m60"))
    {
        // 保存弹匣内子弹数
        int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
        g_iDroppedClip[weapon] = clip;
        
        // 保存备弹
        int primaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
        if (primaryAmmoType != -1)
        {
            int reserve = GetEntProp(client, Prop_Send, "m_iAmmo", _, primaryAmmoType);
            g_iDroppedReserve[weapon] = reserve;
            
            // 清空玩家身上该类型的备弹，防止叠加
            SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, primaryAmmoType);
        }

        // 防消失：如果弹匣为0，设置为1防止被游戏删除
        if (clip <= 0)
        {
            SetEntProp(weapon, Prop_Send, "m_iClip1", 1);
        }
        
        // 重置换弹状态
        g_bIsReloading[client] = false;
        g_iReloadingWeapon[client] = -1;
    }
    return Plugin_Continue;
}

// ==================================================================================================
// 武器装备时恢复弹药数据
// ==================================================================================================

public Action OnWeaponEquip(int client, int weapon)
{
    if (!IsValidEntity(weapon)) return Plugin_Continue;

    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));

    if (StrEqual(classname, "weapon_rifle_m60"))
    {
        DataPack pack = new DataPack();
        pack.WriteCell(GetClientUserId(client));
        pack.WriteCell(EntIndexToEntRef(weapon));
        RequestFrame(Frame_RestoreAmmo, pack);
    }
    return Plugin_Continue;
}

void Frame_RestoreAmmo(DataPack pack)
{
    pack.Reset();
    int userid = pack.ReadCell();
    int weaponRef = pack.ReadCell();
    delete pack;

    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
    
    int weapon = EntRefToEntIndex(weaponRef);
    if (weapon == INVALID_ENT_REFERENCE || !IsValidEntity(weapon)) return;
    if (GetEntPropEnt(weapon, Prop_Send, "m_hOwnerEntity") != client) return;

    int primaryAmmoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if (primaryAmmoType == -1) return;

    // 恢复弹匣内子弹数
    if (g_iDroppedClip[weapon] != -1)
    {
        SetEntProp(weapon, Prop_Send, "m_iClip1", g_iDroppedClip[weapon]);
    }

    // 恢复备弹
    // 方法：先清零当前备弹，防止叠加
    SetEntProp(client, Prop_Send, "m_iAmmo", 0, _, primaryAmmoType);
    
    if (g_iDroppedReserve[weapon] != -1)
    {
        // 该枪存在记录
        SetEntProp(client, Prop_Send, "m_iAmmo", g_iDroppedReserve[weapon], _, primaryAmmoType);
    }
    else
    {
        // 这是一把新枪，给满备弹
        SetEntProp(client, Prop_Send, "m_iAmmo", g_cvReserveAmmo.IntValue, _, primaryAmmoType);
    }

    // 清除记录，防止重复使用
    g_iDroppedReserve[weapon] = -1;
    g_iDroppedClip[weapon] = -1;
}

// ==================================================================================================
// 换弹时利用原生动画，在动画结束时填充弹药
// ==================================================================================================

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) != 2)
        return Plugin_Continue;

    int activeWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(activeWeapon)) return Plugin_Continue;

    char classname[32];
    GetEntityClassname(activeWeapon, classname, sizeof(classname));
    if (!StrEqual(classname, "weapon_rifle_m60")) return Plugin_Continue;

    int clip = GetEntProp(activeWeapon, Prop_Send, "m_iClip1");
    int ammoType = GetEntProp(activeWeapon, Prop_Send, "m_iPrimaryAmmoType");
    int reserve = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
    int maxClip = g_cvClipSize.IntValue;

    // 检查换弹状态
    bool bInReload = view_as<bool>(GetEntProp(activeWeapon, Prop_Send, "m_bInReload"));
    
    // 开始换弹的检测
    if (bInReload && !g_bIsReloading[client])
    {
        g_bIsReloading[client] = true;
        g_iReloadingWeapon[client] = activeWeapon;
    }
    // 换弹结束的检测
    else if (!bInReload && g_bIsReloading[client] && g_iReloadingWeapon[client] == activeWeapon)
    {
        FinishReload(client, activeWeapon);
        g_bIsReloading[client] = false;
        g_iReloadingWeapon[client] = -1;
    }
    // 换枪或其他情况重置状态
    else if (g_bIsReloading[client] && g_iReloadingWeapon[client] != activeWeapon)
    {
        g_bIsReloading[client] = false;
        g_iReloadingWeapon[client] = -1;
    }

    // 如果按下R键，检查是否允许换弹
    if (buttons & IN_RELOAD)
    {
        // 弹夹满了或没有备弹，阻止换弹
        if (clip >= maxClip || reserve <= 0)
        {
            buttons &= ~IN_RELOAD;
            return Plugin_Changed;
        }
    }

    return Plugin_Continue;
}

// 游戏触发的换弹事件（备用检测）
public void Event_WeaponReload(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!client || !IsClientInGame(client)) return;

    int weapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(weapon)) return;

    char classname[32];
    GetEntityClassname(weapon, classname, sizeof(classname));
    
    if (StrEqual(classname, "weapon_rifle_m60"))
    {
        g_bIsReloading[client] = true;
        g_iReloadingWeapon[client] = weapon;
    }
}

void FinishReload(int client, int weapon)
{
    if (!IsValidEntity(weapon)) return;
    
    int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
    if (ammoType == -1) return;

    int clip = GetEntProp(weapon, Prop_Send, "m_iClip1");
    int reserve = GetEntProp(client, Prop_Send, "m_iAmmo", _, ammoType);
    int maxClip = g_cvClipSize.IntValue;

    if (reserve <= 0 || clip >= maxClip) return;

    int needed = maxClip - clip;
    int toLoad = (reserve >= needed) ? needed : reserve;

    SetEntProp(weapon, Prop_Send, "m_iClip1", clip + toLoad);
    SetEntProp(client, Prop_Send, "m_iAmmo", reserve - toLoad, _, ammoType);
}

// ==================================================================================================
// 弹药堆补给
// ==================================================================================================

public Action OnAmmoUse(int entity, int activator, int caller, UseType type, float value)
{
    if (activator < 1 || activator > MaxClients) return Plugin_Continue;
    if (!IsClientInGame(activator) || !IsPlayerAlive(activator)) return Plugin_Continue;

    int weapon = GetEntPropEnt(activator, Prop_Send, "m_hActiveWeapon");
    if (!IsValidEntity(weapon)) return Plugin_Continue;

    char wpnName[32];
    GetEntityClassname(weapon, wpnName, sizeof(wpnName));
    
    if (StrEqual(wpnName, "weapon_rifle_m60"))
    {
        int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
        if (ammoType != -1)
        {
            DataPack pack = new DataPack();
            pack.WriteCell(GetClientUserId(activator));
            pack.WriteCell(EntIndexToEntRef(weapon));
            pack.WriteCell(ammoType);
            RequestFrame(Frame_SetFullAmmo, pack);
        }
    }
    return Plugin_Continue;
}

void Frame_SetFullAmmo(DataPack pack)
{
    pack.Reset();
    int userid = pack.ReadCell();
    int weaponRef = pack.ReadCell();
    int ammoType = pack.ReadCell();
    delete pack;

    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
    
    int weapon = EntRefToEntIndex(weaponRef);
    if (weapon == INVALID_ENT_REFERENCE || !IsValidEntity(weapon)) return;

    // 设置满备弹和满弹匣子弹
    SetEntProp(client, Prop_Send, "m_iAmmo", g_cvReserveAmmo.IntValue, _, ammoType);
    SetEntProp(weapon, Prop_Send, "m_iClip1", g_cvClipSize.IntValue);
}

// ==================================================================================================
// 内存补丁
// ==================================================================================================

void Patch_M60_Drop(Handle hGamedata)
{
    Address patch = GameConfGetAddress(hGamedata, "CRifle_M60::PrimaryAttack");
    if (!patch) 
    { 
        LogError("Failed to get address: CRifle_M60::PrimaryAttack"); 
        return; 
    }
    
    int offset = GameConfGetOffset(hGamedata, "CRifle_M60::PrimaryAttack");
    if (offset == -1) 
    { 
        LogError("Failed to get offset: CRifle_M60::PrimaryAttack"); 
        return; 
    }

    Address targetAddr = patch + view_as<Address>(offset);
    int byte = LoadFromAddress(targetAddr, NumberType_Int8);

    // Windows: 0x75 (JNZ) -> 0xEB (JMP)
    // Linux: 0x85 (TEST) -> 0x8D (LEA, 作为NOP使用)
    if (byte == 0x75)
    {
        g_addrM60Drop = targetAddr;
        g_iM60DropRestore = byte;
        StoreToAddress(g_addrM60Drop, 0xEB, NumberType_Int8);
        PrintToServer("[M60 Fix] Windows patch applied: Prevent Drop (0x75->0xEB)");
    }
    else if (byte == 0x85)
    {
        g_addrM60Drop = targetAddr;
        g_iM60DropRestore = byte;
        StoreToAddress(g_addrM60Drop, 0x8D, NumberType_Int8);
        PrintToServer("[M60 Fix] Linux patch applied: Prevent Drop (0x85->0x8D)");
    }
    else
    {
        LogError("[M60 Fix] Unexpected byte at drop patch location: 0x%02X", byte);
    }
}

void Patch_M60_Ammo(Handle hGamedata)
{
    Address patch = GameConfGetAddress(hGamedata, "CWeaponAmmoSpawn::Use");
    if (!patch) 
    { 
        LogError("Failed to get address: CWeaponAmmoSpawn::Use"); 
        return; 
    }
    
    int offset = GameConfGetOffset(hGamedata, "CWeaponAmmoSpawn::Use_M60_Patch");
    if (offset == -1) 
    { 
        LogError("Failed to get offset: CWeaponAmmoSpawn::Use_M60_Patch"); 
        return; 
    }

    Address targetAddr = patch + view_as<Address>(offset);
    int byte = LoadFromAddress(targetAddr, NumberType_Int8);

    if (byte == 0x25)
    {
        g_addrAmmoUse = targetAddr;
        g_iAmmoUseRestore = byte;
        StoreToAddress(g_addrAmmoUse, 0xFF, NumberType_Int8);
        PrintToServer("[M60 Fix] Patch applied: Allow Ammo Pickup (0x25->0xFF)");
    }
    else
    {
        LogError("[M60 Fix] Unexpected byte at ammo patch location: 0x%02X", byte);
    }
}

public void OnPluginEnd()
{
    // 恢复原始字节
    if (g_addrM60Drop != Address_Null)
    {
        StoreToAddress(g_addrM60Drop, g_iM60DropRestore, NumberType_Int8);
        PrintToServer("[M60 Fix] Restored drop patch");
    }
    
    if (g_addrAmmoUse != Address_Null)
    {
        StoreToAddress(g_addrAmmoUse, g_iAmmoUseRestore, NumberType_Int8);
        PrintToServer("[M60 Fix] Restored ammo patch");
    }
}

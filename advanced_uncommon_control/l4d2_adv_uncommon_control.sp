/*
*	Advanced Riot Control
*	Copyright (C) 2025 HoongDou 
*
*	This plugin is a merger of two original works:
*	- "[L4D2] Riot Uncommon Penetration" by Silvers (https://forums.alliedmods.net/showthread.php?t=341750)
*	- "L4D2 Riot Cop Head Shot" by dcx2 (https://forums.alliedmods.net/showthread.php?t=133463)
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*/
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define PLUGIN_VERSION 		"2.6"
#define CVAR_FLAGS			FCVAR_NOTIFY
#define CONFIG_DATA			"data/l4d2_adv_uncommon_control.cfg" // 配置文件
#define MAX_EDICTS			2048 // 手动定义最大实体数

// --- 全局 CVar ---
ConVar g_hCvarEnable;
ConVar g_hCvarGameMode;
ConVar g_hCvarModes;
ConVar g_hCvarModesOff;
ConVar g_hCvarModesTog;
ConVar g_hCvarRiotBodyPenetration;
ConVar g_hCvarRiotHeadshotMode;
ConVar g_hCvarRiotBodyDamageMultiplier;
ConVar g_hCvarFallenHeadshotMultiplier;
ConVar g_hCvarDebug;

// --- 全局变量 ---
bool g_bPluginEnabled;
bool g_bDebug;
bool g_bRiotBodyPenetrationEnabled; // 缓存Riot穿透开关的值
int g_iRiotHeadshotMode;
float g_fRiotBodyDamageMultiplier;
float g_fFallenHeadshotMultiplier;
float g_fDamageBuffer[MAX_EDICTS]; // 正确的数组大小，用于存储任何实体的临时伤害
StringMap g_hWeaponsConfig;

public Plugin myinfo =
{
   name = "[L4D2] Advanced Uncommon Control",
   author = "Silvers, dcx2 & HoongDou",
   description = "对Riot僵尸穿透、爆头，同时提供了对Fallen Survivor、Jimmy Gibbs的爆头加成。",
   version = PLUGIN_VERSION,
   url = "https://github.com/HoongDou"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
   EngineVersion test = GetEngineVersion();
   if (test != Engine_Left4Dead2)
   {
  	strcopy(error, err_max, "此插件仅支持 Left 4 Dead 2。");
  	return APLRes_SilentFailure;
   }
   return APLRes_Success;
}

public void OnPluginStart()
{
   g_hCvarEnable = CreateConVar("l4d2_riot_advanced_enable", "1", "0=插件关闭, 1=插件开启。", CVAR_FLAGS);
   g_hCvarModes = CreateConVar("l4d2_riot_advanced_modes", "", "在这些游戏模式中开启插件，用逗号分隔(无空格)。(留空=所有模式)", CVAR_FLAGS);
   g_hCvarModesOff = CreateConVar("l4d2_riot_advanced_modes_off", "", "在这些游戏模式中关闭插件，用逗号分隔(无空格)。(留空=无)", CVAR_FLAGS);
   g_hCvarModesTog = CreateConVar("l4d2_riot_advanced_modes_tog", "0", "在这些游戏模式中开启插件。0=所有, 1=Coop, 2=Survival, 4=Versus, 8=Scavenge。数字可相加。", CVAR_FLAGS);
   g_hCvarRiotBodyPenetration = CreateConVar("l4d2_riot_advanced_riot_body_penetration", "1", "是否启用对Riot僵尸的正面身体穿透伤害。0=禁用, 1=启用。此开关不影响爆头逻辑。", CVAR_FLAGS);
   g_hCvarRiotHeadshotMode = CreateConVar("l4d2_riot_advanced_riot_headshot_mode", "1", "Riot僵尸爆头模式。0=禁用, 1=秒杀, 2=正常伤害(仍需从正面穿透或从背后攻击)。", CVAR_FLAGS);
   g_hCvarRiotBodyDamageMultiplier = CreateConVar("l4d2_riot_advanced_riot_body_damage_mult", "1.0", "对Riot僵尸身体穿透伤害的全局乘数 (基于配置文件中的数值)。", CVAR_FLAGS);
   g_hCvarFallenHeadshotMultiplier = CreateConVar("l4d2_riot_advanced_fallen_headshot_mult", "12.0", "对Fallen Survivor和Jimmy Gibbs的爆头伤害乘数。", CVAR_FLAGS);
   g_hCvarDebug = CreateConVar("l4d2_riot_advanced_debug", "0", "为本插件启用调试信息。", CVAR_FLAGS);
   CreateConVar("l4d2_riot_advanced_version", PLUGIN_VERSION, "Advanced Uncommon Control 插件版本。", FCVAR_NOTIFY|FCVAR_DONTRECORD);

   AutoExecConfig(true, "l4d2_advanced_uncommon_control");

   g_hCvarGameMode = FindConVar("mp_gamemode");

   g_hCvarEnable.AddChangeHook(OnCvarStateChanged);
   if (g_hCvarGameMode) g_hCvarGameMode.AddChangeHook(OnCvarStateChanged);
   g_hCvarModes.AddChangeHook(OnCvarStateChanged);
   g_hCvarModesOff.AddChangeHook(OnCvarStateChanged);
   g_hCvarModesTog.AddChangeHook(OnCvarStateChanged);

   g_hCvarRiotBodyPenetration.AddChangeHook(OnCvarsChanged);
   g_hCvarRiotHeadshotMode.AddChangeHook(OnCvarsChanged);
   g_hCvarRiotBodyDamageMultiplier.AddChangeHook(OnCvarsChanged);
   g_hCvarFallenHeadshotMultiplier.AddChangeHook(OnCvarsChanged);
   g_hCvarDebug.AddChangeHook(OnCvarsChanged);
}

public void OnConfigsExecuted()
{
   UpdateCvarCache();
   UpdatePluginState();
}

public void OnMapStart()
{
   LoadWeaponConfig();
}

void OnCvarStateChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
   UpdatePluginState();
}

void OnCvarsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
   UpdateCvarCache();
}

void UpdateCvarCache()
{
   g_bDebug = g_hCvarDebug.BoolValue;
   g_bRiotBodyPenetrationEnabled = g_hCvarRiotBodyPenetration.BoolValue;
   g_iRiotHeadshotMode = g_hCvarRiotHeadshotMode.IntValue;
   g_fRiotBodyDamageMultiplier = g_hCvarRiotBodyDamageMultiplier.FloatValue;
   g_fFallenHeadshotMultiplier = g_hCvarFallenHeadshotMultiplier.FloatValue;
}

// ====================================================================================================
// 插件状态 & 游戏模式逻辑
// ====================================================================================================
void UpdatePluginState()
{
   bool shouldBeEnabled = g_hCvarEnable.BoolValue && IsGameModeAllowed();
   UpdateCvarCache();

   if (g_bPluginEnabled == shouldBeEnabled)
  	return;

   g_bPluginEnabled = shouldBeEnabled;

   // 根据插件状态，为已存在的僵尸挂载或卸载钩子
   for (int i = 1; i <= MaxClients; i++)
   {
  	if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && GetEntProp(i, Prop_Send, "m_zombieClass") == 8) // 普通感染者
  	{
 		OnInfectedSpawned(i);
  	}
   }
}

bool IsGameModeAllowed()
{
   if (g_hCvarGameMode == null)
  	return true;

   char sGameMode[64];
   g_hCvarGameMode.GetString(sGameMode, sizeof(sGameMode));

   char sAllowedModes[128];
   g_hCvarModes.GetString(sAllowedModes, sizeof(sAllowedModes));
   if (sAllowedModes[0] && StrContains(sAllowedModes, sGameMode, false) == -1)
  	return false;
   
   char sDisallowedModes[128];
   g_hCvarModesOff.GetString(sDisallowedModes, sizeof(sDisallowedModes));
   if (sDisallowedModes[0] && StrContains(sDisallowedModes, sGameMode, false) != -1)
  	return false;

   int iCvarModesTog = g_hCvarModesTog.IntValue;
   if (iCvarModesTog > 0)
   {
  	if (strcmp(sGameMode, "coop", false) == 0 || strcmp(sGameMode, "realism", false) == 0) {
 		if (!(iCvarModesTog & 1)) return false;
  	} else if (strcmp(sGameMode, "survival", false) == 0) {
 		if (!(iCvarModesTog & 2)) return false;
  	} else if (strcmp(sGameMode, "versus", false) == 0 || strcmp(sGameMode, "teamversus", false) == 0) {
 		if (!(iCvarModesTog & 4)) return false;
  	} else if (strcmp(sGameMode, "scavenge", false) == 0 || strcmp(sGameMode, "teamscavenge", false) == 0) {
 		if (!(iCvarModesTog & 8)) return false;
  	}
   }
   return true;
}

// ====================================================================================================
// 武器配置
// ====================================================================================================
void LoadWeaponConfig()
{
   char sPath[PLATFORM_MAX_PATH];
   BuildPath(Path_SM, sPath, sizeof(sPath), CONFIG_DATA);
   if (!FileExists(sPath))
   {
  	SetFailState("缺少必要的配置文件: \"%s\"。", sPath);
  	return;
   }

   if (g_hWeaponsConfig) delete g_hWeaponsConfig;
   g_hWeaponsConfig = new StringMap();
   g_hWeaponsConfig.SetValue("weapon_melee", 3.14); // 近战武器的特殊标记值

   KeyValues hFile = new KeyValues("weapons");
   if (!hFile.ImportFromFile(sPath))
   {
  	delete hFile;
  	SetFailState("加载配置文件时出错: \"%s\"。", sPath);
  	return;
   }

   char sClass[64];
   hFile.GotoFirstSubKey();
   do
   {
  	hFile.GetSectionName(sClass, sizeof(sClass));
  	g_hWeaponsConfig.SetValue(sClass, hFile.GetFloat("damage"));
   } while (hFile.GotoNextKey());

   delete hFile;
}

// ====================================================================================================
// 实体挂钩
// ====================================================================================================
public void OnEntityCreated(int entity, const char[] classname)
{
   if (strcmp(classname, "infected") == 0)
   {
  	SDKHook(entity, SDKHook_SpawnPost, OnInfectedSpawned);
   }
}

void OnInfectedSpawned(int entity)
{
   // 确保在插件被禁用时移除钩子
   SDKUnhook(entity, SDKHook_SpawnPost, OnInfectedSpawned);
   SDKUnhook(entity, SDKHook_TraceAttack, OnTraceAttack);
   SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
   SDKUnhook(entity, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
   SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);

   if (!g_bPluginEnabled || !IsValidEntity(entity))
   {
  	return;
   }

   char model[128];
   GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));

   if (StrContains(model, "riot", false) != -1) // Riot Cop
   {
   //总是挂载TraceAttack钩子，以确保爆头逻辑始终可以被检测
  	SDKHook(entity, SDKHook_TraceAttack, OnTraceAttack);
	if (g_bDebug) PrintToServer("[AdvUncommon] Hooked OnTraceAttack for Riot Cop (Edict %d) for headshot detection.", entity);
	// 只有在身体穿透开关开启时，才挂载处理身体伤害的钩子链
  	if (g_bRiotBodyPenetrationEnabled)
  	{
  	SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
  	SDKHook(entity, SDKHook_OnTakeDamageAlive, OnTakeDamageAlive);
  	SDKHook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
  	if (g_bDebug) PrintToServer("[AdvUncommon] Hooked body damage chain for Riot Cop (Edict %d) - Body Penetration Enabled.", entity);
   }
   }
   else if (StrContains(model, "fallen", false) != -1 || StrContains(model, "jimmy", false) != -1) // Fallen Survivor or Jimmy Gibbs
   {
  	SDKHook(entity, SDKHook_TraceAttack, OnTraceAttack);
  	if (g_bDebug) PrintToServer("[AdvUncommon] Hooked Fallen/Jimmy (Edict %d)", entity);
   }
}

// ====================================================================================================
// 核心逻辑 - OnTraceAttack (处理爆头)
// ====================================================================================================
public Action OnTraceAttack(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
   if (!g_bPluginEnabled || !IsSurvivor(attacker))
   {
  	return Plugin_Continue;
   }

   // 仅处理对普通感染者的伤害
   char classname[64];
   GetEdictClassname(victim, classname, sizeof(classname));
   if (strcmp(classname, "infected") != 0)
   {
  	return Plugin_Continue;
   }

   char model[128];
   GetEntPropString(victim, Prop_Data, "m_ModelName", model, sizeof(model));

   // --- Riot Cop 爆头逻辑 ---
	if (g_iRiotHeadshotMode > 0 && hitgroup == 1 && StrContains(model, "riot", false) != -1)
	{
		if (g_iRiotHeadshotMode == 1) // 模式1：秒杀
		{
			// 直接使用SDKHooks施加伤害，绕过引擎的护甲计算
			float lethalDamage = float(GetEntProp(victim, Prop_Data, "m_iHealth")) + 50.0;
			SDKHooks_TakeDamage(victim, inflictor, attacker, lethalDamage, DMG_GENERIC);
        
			// 将原始伤害设置为0，防止引擎再造成一次（虽然会被格挡）伤害
			damage = 0.0;
        
			if (g_bDebug) PrintToChat(attacker, "[AdvUncommon] Riot Cop 爆头: 秒杀 (直接造成 %.1f 伤害)", lethalDamage);
        
			// 返回Plugin_Changed来确认我们修改了伤害值（虽然是改为0）
			return Plugin_Changed;
		}
		if (g_bDebug) PrintToChat(attacker, "[AdvUncommon] Riot Cop 爆头: 正常伤害模式");
		return Plugin_Continue; // 对于模式2，仍然需要后续的穿透逻辑，所以保持Continue
	}

   // --- Fallen/Jimmy 爆头逻辑 ---
   if (g_fFallenHeadshotMultiplier > 1.0 && hitgroup == 1 && (StrContains(model, "fallen", false) != -1 || StrContains(model, "jimmy", false) != -1))
   {
  	float newDamage = damage * g_fFallenHeadshotMultiplier;
  	bool isJimmy = StrContains(model, "jimmy", false) != -1;
  	
  	if (isJimmy && newDamage < 3000.0)
  	{
 		if (ammotype == 2 || ammotype == 9 || ammotype == 10)
 		{
			newDamage = 3000.0;
 		}
  	}

  	if (g_bDebug) PrintToChat(attacker, "[AdvUncommon] %s 爆头: %.1f -> %.1f", isJimmy ? "Jimmy Gibbs" : "Fallen", damage, newDamage);
  	
  	damage = newDamage;
  	return Plugin_Changed;
   }

   return Plugin_Continue;
}

// ====================================================================================================
// 核心逻辑 - 身体穿透
// ====================================================================================================
// **FIXED**: Corrected the function prototype for OnTakeDamage to match the SDKHook standard.
public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
   if (victim >= 0 && victim < MAX_EDICTS)
   {
  	g_fDamageBuffer[victim] = damage;
   }
   return Plugin_Continue;
}

// OnTakeDamageAlive's prototype is correct.
public Action OnTakeDamageAlive(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
   if (victim >= 0 && victim < MAX_EDICTS)
   {
  	g_fDamageBuffer[victim] = 0.0;
   }
   return Plugin_Continue;
}

// OnTakeDamagePost's prototype is correct.
public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype, int weapon, const float damageForce[3], const float damagePosition[3], int damagecustom)
{
   if (victim < 0 || victim >= MAX_EDICTS || g_fDamageBuffer[victim] <= 0.0)
   {
  	return;
   }

   float finalDamage = 0.0;
   
   if (weapon == 0 && inflictor > 0 && inflictor <= GetMaxEntities())
   {
  	weapon = inflictor;
   }

   if (weapon > 0 && IsValidEntity(weapon))
   {
  	char weaponClass[64];
  	GetEdictClassname(weapon, weaponClass, sizeof(weaponClass));
  	float configDmg;

  	if (g_hWeaponsConfig.GetValue(weaponClass, configDmg))
  	{
 		if (configDmg == 3.14) // 近战武器
 		{
			char meleeName[64];
			GetEntPropString(weapon, Prop_Data, "m_strMapSetScriptName", meleeName, sizeof(meleeName));
			if (g_hWeaponsConfig.GetValue(meleeName, configDmg))
			{
   			finalDamage = configDmg;
			}
 		}
 		else
 		{
			finalDamage = configDmg;
 		}
  	}
   }
   
   if (finalDamage == 0.0)
   {
  	finalDamage = g_fDamageBuffer[victim];
   }

   finalDamage *= g_fRiotBodyDamageMultiplier;
   g_fDamageBuffer[victim] = 0.0;

   if (finalDamage > 0.0 && IsSurvivor(attacker))
   {
  	if (g_bDebug) PrintToChat(attacker, "[AdvUncommon] Riot Cop 身体穿透: 造成 %.1f 伤害。", finalDamage);
  	SDKHooks_TakeDamage(victim, inflictor, attacker, finalDamage, DMG_GENERIC);
   }
}

// ====================================================================================================
// 实用函数
// ====================================================================================================
stock bool IsSurvivor(int client)
{
   return (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2);
}

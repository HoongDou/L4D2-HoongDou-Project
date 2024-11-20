#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#define GAMEDATA "rygive"
#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"
#define NAME_InfectedAttackSurvivorTeam "Infected::AttackSurvivorTeam"

StringMap g_aSteamIDs;

Handle g_hSDK_Call_RoundRespawn;
Handle g_hSDK_Call_SetHumanSpec;
Handle g_hSDK_Call_TakeOverBot;
Handle g_hSDK_Call_GoAwayFromKeyboard;
Handle g_hSDK_Call_CreateSmoker;
Handle g_hSDK_Call_CreateBoomer;
Handle g_hSDK_Call_CreateHunter;
Handle g_hSDK_Call_CreateSpitter;
Handle g_hSDK_Call_CreateJockey;
Handle g_hSDK_Call_CreateCharger;
Handle g_hSDK_Call_CreateTank;
Handle g_hSDK_Call_InfectedAttackSurvivorTeam;

Address g_pRespawn;
Address g_pResetStatCondition;

int g_iMeleeClassCount;
int g_iClipSize_RifleM60;
int g_iClipSize_GrenadeLauncher;
int g_iFunction[MAXPLAYERS + 1];
int g_iCurrentPage[MAXPLAYERS + 1];

float g_fSpeedUp[MAXPLAYERS + 1] = {1.0};

bool g_bDebug;
bool g_bWeaponHandling;

char g_sMeleeClass[16][32];
char g_sItemName[MAXPLAYERS + 1][64];

static const char g_sMeleeModels[][] = 
{
    "models/weapons/melee/v_fireaxe.mdl",
    "models/weapons/melee/w_fireaxe.mdl",
    "models/weapons/melee/v_frying_pan.mdl",
    "models/weapons/melee/w_frying_pan.mdl",
    "models/weapons/melee/v_machete.mdl",
    "models/weapons/melee/w_machete.mdl",
    "models/weapons/melee/v_bat.mdl",
    "models/weapons/melee/w_bat.mdl",
    "models/weapons/melee/v_crowbar.mdl",
    "models/weapons/melee/w_crowbar.mdl",
    "models/weapons/melee/v_cricket_bat.mdl",
    "models/weapons/melee/w_cricket_bat.mdl",
    "models/weapons/melee/v_tonfa.mdl",
    "models/weapons/melee/w_tonfa.mdl",
    "models/weapons/melee/v_katana.mdl",
    "models/weapons/melee/w_katana.mdl",
    "models/weapons/melee/v_electric_guitar.mdl",
    "models/weapons/melee/w_electric_guitar.mdl",
    "models/v_models/v_knife_t.mdl",
    "models/w_models/weapons/w_knife_t.mdl",
    "models/weapons/melee/v_golfclub.mdl",
    "models/weapons/melee/w_golfclub.mdl",
    "models/weapons/melee/v_shovel.mdl",
    "models/weapons/melee/w_shovel.mdl",
    "models/weapons/melee/v_pitchfork.mdl",
    "models/weapons/melee/w_pitchfork.mdl",
    "models/weapons/melee/v_riotshield.mdl",
    "models/weapons/melee/w_riotshield.mdl"
};

static const char g_sSpecialsInfectedModels[][] = 
{
    "models/infected/smoker.mdl",
    "models/infected/boomer.mdl",
    "models/infected/hunter.mdl",
    "models/infected/spitter.mdl",
    "models/infected/jockey.mdl",
    "models/infected/charger.mdl",
    "models/infected/hulk.mdl",
    "models/infected/witch.mdl",
    "models/infected/witch_bride.mdl"
};

static const char g_sUncommonInfectedModels[][] = 
{
    "models/infected/common_male_riot.mdl",
    "models/infected/common_male_ceda.mdl",
    "models/infected/common_male_clown.mdl",
    "models/infected/common_male_mud.mdl",
    "models/infected/common_male_roadcrew.mdl",
    "models/infected/common_male_jimmy.mdl",
    "models/infected/common_male_fallen_survivor.mdl"
};

static const char g_sMeleeName[][] = 
{
    "fireaxe",          // 斧头
    "frying_pan",       // 平底锅
    "machete",          // 砍刀
    "baseball_bat",     // 棒球棒
    "crowbar",          // 撬棍
    "cricket_bat",      // 球拍
    "tonfa",            // 警棍
    "katana",           // 武士刀
    "electric_guitar",  // 吉他
    "knife",            // 小刀
    "golfclub",         // 高尔夫球棍
    "shovel",           // 铁铲
    "pitchfork",        // 草叉
    "riotshield"        // 盾牌
};

static const char g_sMeleeTrans[][] = 
{
    "斧头",
    "平底锅",
    "砍刀",
    "棒球棒",
    "撬棍",
    "球拍",
    "警棍",
    "武士刀",
    "吉他",
    "小刀",
    "高尔夫球棍",
    "铁铲",
    "草叉",
    "盾牌"
};

enum L4D2WeaponType
{
    L4D2WeaponType_Unknown = 0,
    L4D2WeaponType_Pistol,
    L4D2WeaponType_Magnum,
    L4D2WeaponType_Rifle,
    L4D2WeaponType_RifleAk47,
    L4D2WeaponType_RifleDesert,
    L4D2WeaponType_RifleM60,
    L4D2WeaponType_RifleSg552,
    L4D2WeaponType_HuntingRifle,
    L4D2WeaponType_SniperAwp,
    L4D2WeaponType_SniperMilitary,
    L4D2WeaponType_SniperScout,
    L4D2WeaponType_SMG,
    L4D2WeaponType_SMGSilenced,
    L4D2WeaponType_SMGMp5,
    L4D2WeaponType_Autoshotgun,
    L4D2WeaponType_AutoshotgunSpas,
    L4D2WeaponType_Pumpshotgun,
    L4D2WeaponType_PumpshotgunChrome,
    L4D2WeaponType_Molotov,
    L4D2WeaponType_Pipebomb,
    L4D2WeaponType_FirstAid,
    L4D2WeaponType_Pills,
    L4D2WeaponType_Gascan,
    L4D2WeaponType_Oxygentank,
    L4D2WeaponType_Propanetank,
    L4D2WeaponType_Vomitjar,
    L4D2WeaponType_Adrenaline,
    L4D2WeaponType_Chainsaw,
    L4D2WeaponType_Defibrilator,
    L4D2WeaponType_GrenadeLauncher,
    L4D2WeaponType_Melee,
    L4D2WeaponType_UpgradeFire,
    L4D2WeaponType_UpgradeExplosive,
    L4D2WeaponType_BoomerClaw,
    L4D2WeaponType_ChargerClaw,
    L4D2WeaponType_HunterClaw,
    L4D2WeaponType_JockeyClaw,
    L4D2WeaponType_SmokerClaw,
    L4D2WeaponType_SpitterClaw,
    L4D2WeaponType_TankClaw,
    L4D2WeaponType_Gnome
};

// l4d_info_editor
forward void OnGetWeaponsInfo(int pThis, const char[] classname);
native void InfoEditor_GetString(int pThis, const char[] keyname, char[] dest, int destLen);

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("InfoEditor_GetString");
	return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "WeaponHandling"))
	{
		g_bWeaponHandling = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "WeaponHandling"))
	{
		g_bWeaponHandling = false;
	}
}

public Plugin myinfo =
{
	name = "Give Item Menu",
	description = "Gives Item Menu",
	author = "Ryanx, sorallll, HoongDou",
	version = "1.0.2",
	url = ""
};

public void OnPluginStart()
{
	LoadGameData();

	CreateConVar("rygive_version", "1.0.2", "rygive功能插件", FCVAR_NOTIFY | FCVAR_DONTRECORD);

	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);

	RegAdminCmd("sm_rygive", RygiveMenu, ADMFLAG_ROOT, "rygive");

	g_aSteamIDs = new StringMap();
}

public void OnPluginEnd()
{
	PatchAddress(false);
}

public void OnGetWeaponsInfo(int pThis, const char[] classname)
{
	char sResult[64];
	if (StrEqual(classname, "weapon_rifle_m60"))
	{
		InfoEditor_GetString(pThis, "clip_size", sResult, sizeof(sResult));
		g_iClipSize_RifleM60 = StringToInt(sResult);
	}
	else if (StrEqual(classname, "weapon_grenade_launcher"))
	{
		InfoEditor_GetString(pThis, "clip_size", sResult, sizeof(sResult));
		g_iClipSize_GrenadeLauncher = StringToInt(sResult);
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_fSpeedUp[client] = 1.0;

	if (!g_bDebug || IsFakeClient(client))
	{
		return;
	}

	char sSteamID[64];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	bool bAllowed;
	if (!g_aSteamIDs.GetValue(sSteamID, bAllowed))
	{
		KickClient(client, "服务器调试中...");
	}
}

public void OnMapStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_fSpeedUp[i] = 1.0;
	}

	int iLen = sizeof(g_sMeleeModels);
	for (int i = 0; i < iLen; i++)
	{
		if (!IsModelPrecached(g_sMeleeModels[i]))
		{
			PrecacheModel(g_sMeleeModels[i], true);
		}
	}

	iLen = sizeof(g_sSpecialsInfectedModels);
	for (int i = 0; i < iLen; i++)
	{
		if (!IsModelPrecached(g_sSpecialsInfectedModels[i]))
		{
			PrecacheModel(g_sSpecialsInfectedModels[i], true);
		}
	}

	iLen = sizeof(g_sUncommonInfectedModels);
	for (int i = 0; i < iLen; i++)
	{
		if (!IsModelPrecached(g_sUncommonInfectedModels[i]))
		{
			PrecacheModel(g_sUncommonInfectedModels[i], true);
		}
	}

	iLen = sizeof(g_sMeleeName);
	char sBuffer[64];
	for (int i = 0; i < iLen; i++)
	{
		FormatEx(sBuffer, sizeof(sBuffer), "scripts/melee/%s.txt", g_sMeleeName[i]);
		if (!IsGenericPrecached(sBuffer))
		{
			PrecacheGeneric(sBuffer, true);
		}
	}

	GetMeleeClasses();
}

void GetMeleeClasses()
{
	int iMeleeStringTable = FindStringTable("MeleeWeapons");
	g_iMeleeClassCount = GetStringTableNumStrings(iMeleeStringTable);

	for (int i = 0; i < g_iMeleeClassCount; i++)
	{
		ReadStringTable(iMeleeStringTable, i, g_sMeleeClass[i], sizeof(g_sMeleeClass[]));
	}
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if ((client != 0 && !IsFakeClient(client)) && !RealPlayerExist(client))
	{
		g_aSteamIDs.Clear();
		g_bDebug = false;
	}
}

bool RealPlayerExist(int iExclude = 0)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (client != iExclude && IsClientConnected(client) && !IsFakeClient(client))
		{
			return true;
		}
	}
	return false;
}

public Action RygiveMenu(int client, int args)
{
	if (client && IsClientInGame(client))
	{
		Rygive(client);
	}

	return Plugin_Handled;
}

public Action Rygive(int client)
{
	Menu menu = new Menu(MenuHandler_Rygive);
	menu.SetTitle("多功能插件");
	menu.AddItem("w", "武器");
	menu.AddItem("i", "物品");
	menu.AddItem("z", "感染");
	menu.AddItem("o", "杂项");
	menu.AddItem("t", "团队控制");

	if (g_bWeaponHandling)
	{
		menu.AddItem("c", "武器操纵性");
	}

	if (GetClientImmunityLevel(client) > 98)
	{
		menu.AddItem("d", g_bDebug ? "关闭调试模式" : "开启调试模式");
	}

	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

int GetClientImmunityLevel(int client)
{
	char sSteamID[64];
	GetClientAuthId(client, AuthId_Steam2, sSteamID, sizeof(sSteamID));
	AdminId admin = FindAdminByIdentity(AUTHMETHOD_STEAM, sSteamID);
	if (admin == INVALID_ADMIN_ID)
	{
		return -999;
	}

	return GetAdminImmunityLevel(admin);
}

public int MenuHandler_Rygive(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[2];
			menu.GetItem(param2, sItem, sizeof(sItem));
			switch (sItem[0])
			{
				case 'w':
					Action_Weapons(client);
				case 'i':
					Action_Items(client, 0);
				case 'z':
					Action_Infected(client, 0);
				case 'o':
					Action_Othoer(client, 0);
				case 't':
					Action_TeamSwitch(client, 0);
				case 'c':
					Action_HandlingAPI(client, 0);
				case 'd':
					Action_DebugMode(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}



void Action_Weapons(int client)
{
	Menu menu = new Menu(MenuHandler_Weapons);
	menu.SetTitle("武器");
	menu.AddItem("0", "枪械");
	menu.AddItem("1", "近战");
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_Weapons(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			g_iCurrentPage[client] = menu.Selection;
			switch (param2)
			{
				case 0: Gun_Menu(client, 0); 
				case 1: Melee_Menu(client, 0);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Rygive(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void Gun_Menu(int client, int index)
{
	Menu menu = new Menu(MenuHandler_Gun);
	menu.SetTitle("枪械");
	menu.AddItem("pistol", "手枪");
	menu.AddItem("pistol_magnum", "马格南");
	menu.AddItem("chainsaw", "电锯");
	menu.AddItem("smg", "UZI微冲");
	menu.AddItem("smg_mp5", "MP5");
	menu.AddItem("smg_silenced", "MAC微冲");
	menu.AddItem("pumpshotgun", "木喷");
	menu.AddItem("shotgun_chrome", "铁喷");
	menu.AddItem("rifle", "M16步枪");
	menu.AddItem("rifle_desert", "三连步枪");
	menu.AddItem("rifle_ak47", "AK47");
	menu.AddItem("rifle_sg552", "SG552");
	menu.AddItem("autoshotgun", "一代连喷");
	menu.AddItem("shotgun_spas", "二代连喷");
	menu.AddItem("hunting_rifle", "木狙");
	menu.AddItem("sniper_military", "军狙");
	menu.AddItem("sniper_scout", "鸟狙");
	menu.AddItem("sniper_awp", "AWP");
	menu.AddItem("rifle_m60", "M60");
	menu.AddItem("grenade_launcher", "榴弹发射器");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_Gun(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[64];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				g_iFunction[client] = 1;
				g_iCurrentPage[client] = menu.Selection;
				FormatEx(g_sItemName[client], sizeof(g_sItemName[]), "give %s", sItem);
				ListAliveSurvivor(client);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Action_Weapons(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void Melee_Menu(int client, int index)
{
	Menu menu = new Menu(MenuHandler_Melee);
	menu.SetTitle("近战");
	for (int i = 0; i < g_iMeleeClassCount; i++)
	{
		int iTrans = GetMeleeTrans(g_sMeleeClass[i]);
		if (iTrans != -1)
		{
			menu.AddItem(g_sMeleeClass[i], g_sMeleeTrans[iTrans]);
		}
		else
		{
			menu.AddItem(g_sMeleeClass[i], g_sMeleeClass[i]); // 自定义近战显示默认脚本名称
		}
	}
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

int GetMeleeTrans(const char[] sMeleeName)
{
	for (int i = 0; i < sizeof(g_sMeleeName); i++)
	{
		if (StrEqual(g_sMeleeName[i], sMeleeName))
		{
			return i;
		}
	}
	return -1;
}

public int MenuHandler_Melee(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[64];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				g_iFunction[client] = 2;
				g_iCurrentPage[client] = menu.Selection;
				FormatEx(g_sItemName[client], sizeof(g_sItemName[]), "give %s", sItem);
				ListAliveSurvivor(client);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Action_Weapons(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void Action_Items(int client, int index)
{
	Menu menu = new Menu(MenuHandler_Items);
	menu.SetTitle("物品");
	menu.AddItem("health", "生命值");
	menu.AddItem("molotov", "燃烧瓶");
	menu.AddItem("pipe_bomb", "管状炸弹");
	menu.AddItem("vomitjar", "胆汁瓶");
	menu.AddItem("first_aid_kit", "医疗包");
	menu.AddItem("defibrillator", "电击器");
	menu.AddItem("upgradepack_incendiary", "燃烧弹药包");
	menu.AddItem("upgradepack_explosive", "高爆弹药包");
	menu.AddItem("adrenaline", "肾上腺素");
	menu.AddItem("pain_pills", "止痛药");
	menu.AddItem("gascan", "汽油桶");
	menu.AddItem("propanetank", "煤气罐");
	menu.AddItem("oxygentank", "氧气瓶");
	menu.AddItem("fireworkcrate", "烟花箱");
	menu.AddItem("cola_bottles", "可乐瓶");
	menu.AddItem("gnome", "圣诞老人");
	menu.AddItem("ammo", "普通弹药");
	menu.AddItem("incendiary_ammo", "燃烧弹药");
	menu.AddItem("explosive_ammo", "高爆弹药");
	menu.AddItem("laser_sight", "激光瞄准器");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_Items(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[64];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				g_iFunction[client] = 3;
				g_iCurrentPage[client] = menu.Selection;

				if (param2 < 17)
				{
					FormatEx(g_sItemName[client], sizeof(g_sItemName[]), "give %s", sItem);
				}
				else
				{
					FormatEx(g_sItemName[client], sizeof(g_sItemName[]), "upgrade_add %s", sItem);
				}
				
				ListAliveSurvivor(client);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Rygive(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void Action_Infected(int client, int index)
{
	Menu menu = new Menu(MenuHandler_Infected);
	menu.SetTitle("感染");
	menu.AddItem("Smoker", "Smoker");
	menu.AddItem("Boomer", "Boomer");
	menu.AddItem("Hunter", "Hunter");
	menu.AddItem("Jockey", "Jockey");
	menu.AddItem("Spitter", "Spitter");
	menu.AddItem("Charger", "Charger");
	menu.AddItem("Tank", "Tank");
	menu.AddItem("Witch", "Witch");
	menu.AddItem("Witch_Bride", "Bride Witch");
	menu.AddItem("Common", "Common");
	menu.AddItem("0", "Riot");
	menu.AddItem("1", "Ceda");
	menu.AddItem("2", "Clown");
	menu.AddItem("3", "Mudmen");
	menu.AddItem("4", "Roadworker");
	menu.AddItem("5", "Jimmie Gibbs");
	menu.AddItem("6", "Fallen Survivor");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_Infected(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[128];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				int iKick = 0;
				if (GetClientCount(false) >= (MaxClients - 1))
				{
					PrintToChat(client, "尝试踢出死亡的感染机器人...");
					iKick = KickDeadInfectedBots(client);
				}
	
				if (iKick <= 0)
				{
					CreateInfectedWithParams(client, sItem, 0, 5);
				}
				else
				{
					DataPack datapack = new DataPack();
					datapack.WriteCell(client);
					datapack.WriteString(sItem);
					RequestFrame(OnNextFrame_CreateInfected, datapack);
				}
			}

			Action_Infected(client, menu.Selection);
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Rygive(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

public void OnNextFrame_CreateInfected(DataPack datapack)
{
	datapack.Reset();
	int client = datapack.ReadCell();
	char sZombie[128];
	datapack.ReadString(sZombie, sizeof(sZombie));
	delete datapack;
	
	CreateInfectedWithParams(client, sZombie, 0, 5);
}

int CreateInfectedWithParams(int client, const char[] sZombie, int iMode = 0, int iNumber = 1)
{
	float vPos[3], vAng[3];
	GetClientAbsOrigin(client, vPos);
	GetClientAbsAngles(client, vAng);

	if (iMode <= 0)
	{
		GetClientEyePosition(client, vPos);
		GetClientEyeAngles(client, vAng);
		TR_TraceRayFilter(vPos, vAng, MASK_OPAQUE, RayType_Infinite, TraceRayDontHitPlayers, client);

		if (TR_DidHit())
		{
			TR_GetEndPosition(vPos);
		}
	}

	vAng[0] = 0.0;
	vAng[2] = 0.0;

	int infected = -1;
	for (int i = 0; i < iNumber; i++)
	{
		infected = CreateInfected(sZombie, vPos, vAng);
		if (IsValidEntity(infected))
		{
			break;
		}
	}

	return infected;
}

bool TraceRayDontHitPlayers(int entity, int contentsMask, any data)
{
	return !IsValidClient(data);
}

int CreateInfected(const char[] sZombie, const float vPos[3], const float vAng[3])
{
	int iBot = -1;

	if (StrEqual(sZombie, "witch", false) || StrEqual(sZombie, "witch_bride", false))
	{
		int witch = CreateEntityByName("witch");
		TeleportEntity(witch, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(witch);
		ActivateEntity(witch);

		if (StrEqual(sZombie, "witch_bride", false))
		{
			SetEntityModel(witch, g_sSpecialsInfectedModels[8]);
		}

		return witch;
	}
	else if (StrEqual(sZombie, "smoker", false))
	{
		iBot = SDKCall(g_hSDK_Call_CreateSmoker, "Smoker");
		if (IsValidClient(iBot))
		{
			SetEntityModel(iBot, g_sSpecialsInfectedModels[0]);
		}
	}
	else if (StrEqual(sZombie, "boomer", false))
	{
		iBot = SDKCall(g_hSDK_Call_CreateBoomer, "Boomer");
		if (IsValidClient(iBot))
		{
			SetEntityModel(iBot, g_sSpecialsInfectedModels[1]);
		}
	}
	else if (StrEqual(sZombie, "hunter", false))
	{
		iBot = SDKCall(g_hSDK_Call_CreateHunter, "Hunter");
		if (IsValidClient(iBot))
		{
			SetEntityModel(iBot, g_sSpecialsInfectedModels[2]);
		}
	}
	else if (StrEqual(sZombie, "spitter", false))
	{
		iBot = SDKCall(g_hSDK_Call_CreateSpitter, "Spitter");
		if (IsValidClient(iBot))
		{
			SetEntityModel(iBot, g_sSpecialsInfectedModels[3]);
		}
	}
	else if (StrEqual(sZombie, "jockey", false))
	{
		iBot = SDKCall(g_hSDK_Call_CreateJockey, "Jockey");
		if (IsValidClient(iBot))
		{
			SetEntityModel(iBot, g_sSpecialsInfectedModels[4]);
		}
	}
	else if (StrEqual(sZombie, "charger", false))
	{
		iBot = SDKCall(g_hSDK_Call_CreateCharger, "Charger");
		if (IsValidClient(iBot))
		{
			SetEntityModel(iBot, g_sSpecialsInfectedModels[5]);
		}
	}
	else if (StrEqual(sZombie, "tank", false))
	{
		iBot = SDKCall(g_hSDK_Call_CreateTank, "Tank");
		if (IsValidClient(iBot))
		{
			SetEntityModel(iBot, g_sSpecialsInfectedModels[6]);
		}
	}
	else
	{
		int infected = CreateEntityByName("infected");
		if (!StrEqual(sZombie, "common", false))
		{
			SetEntityModel(infected, g_sUncommonInfectedModels[StringToInt(sZombie)]);
		}
			
		TeleportEntity(infected, vPos, vAng, NULL_VECTOR);
		DispatchSpawn(infected);
		ActivateEntity(infected);
		CreateTimer(0.4, Timer_Chase, infected);
	
		return infected;
	}
	
	if (IsValidClient(iBot))
	{
		ChangeClientTeam(iBot, 3);
		SetEntProp(iBot, Prop_Send, "m_usSolidFlags", 16);
		SetEntProp(iBot, Prop_Send, "movetype", 2);
		SetEntProp(iBot, Prop_Send, "deadflag", 0);
		SetEntProp(iBot, Prop_Send, "m_lifeState", 0);
		SetEntProp(iBot, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(iBot, Prop_Send, "m_iPlayerState", 0);
		SetEntProp(iBot, Prop_Send, "m_zombieState", 0);
		DispatchSpawn(iBot);
		ActivateEntity(iBot);
		
		DataPack datapack = new DataPack();
		datapack.WriteFloat(vPos[0]);
		datapack.WriteFloat(vPos[1]);
		datapack.WriteFloat(vPos[2]);
		datapack.WriteFloat(vAng[1]);
		datapack.WriteCell(iBot);
		RequestFrame(OnNextFrame_SetPos, datapack);
	}
	
	return iBot;
}

Action Timer_Chase(Handle timer, int infected)
{
	if (!IsValidEntity(infected))
	{
		return Plugin_Stop;
	}

	char class[64];
	GetEntityClassname(infected, class, sizeof(class));
	if (!StrEqual(class, "infected", false))
	{
		return Plugin_Stop;
	}

	SDKCall(g_hSDK_Call_InfectedAttackSurvivorTeam, infected);
	return Plugin_Continue;
}

public void OnNextFrame_SetPos(DataPack datapack)
{
	datapack.Reset();
	float vPos[3];
	float vAng[3];
	vPos[0] = datapack.ReadFloat();
	vPos[1] = datapack.ReadFloat();
	vPos[2] = datapack.ReadFloat();
	vAng[1] = datapack.ReadFloat();
	int iBot = datapack.ReadCell();
	delete datapack;

	TeleportEntity(iBot, vPos, vAng, NULL_VECTOR);
}

int KickDeadInfectedBots(int client)
{
	int iKickedBots = 0;
	for (int iLoopClient = 1; iLoopClient <= MaxClients; iLoopClient++)
	{
		if (!IsValidClient(iLoopClient))
		{
			continue;
		}

		if (!IsInfected(iLoopClient) || !IsFakeClient(iLoopClient) || IsPlayerAlive(iLoopClient))
		{
			continue;
		}
	
		KickClient(iLoopClient);
		iKickedBots++;
	}

	if (iKickedBots > 0)
	{
		PrintToChat(client, "Kicked %i bots.", iKickedBots);
	}

	return iKickedBots;
}

bool IsInfected(int client)
{
	return IsValidClient(client) && GetClientTeam(client) == 3;
}

bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

void Action_Othoer(int client, int index)
{
	Menu menu = new Menu(MenuHandler_Othoer);
	menu.SetTitle("杂项");
	menu.AddItem("0", "倒地");
	menu.AddItem("1", "剥夺");
	menu.AddItem("2", "复活");
	menu.AddItem("3", "传送");
	menu.AddItem("4", "友伤");
	menu.AddItem("5", "召唤尸潮");
	menu.AddItem("6", "剔除所有Bot");
	menu.AddItem("7", "处死所有特感");
	menu.AddItem("8", "处死所有生还");
	menu.AddItem("9", "传送所有生还到起点");
	menu.AddItem("10", "传送所有生还到终点");
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_Othoer(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[64];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				switch (param2)
				{
					case 0: IncapSurvivor(client, 0);
					case 1: StripWeapon(client, 0);
					case 2: RespawnSurvivor(client, 0);
					case 3: TeleportPlayer(client, 0);
					case 4: FriendlyFire(client);
					case 5: ForcePanicEvent(client);
					case 6: KickAllSurvivorBot(client);
					case 7: SlayAllInfected();
					case 8: SlayAllSurvivor();
					case 9: WarpAllSurvivorsToStartArea();
					case 10: WarpAllSurvivorsToCheckpoint();
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Rygive(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void IncapSurvivor(int client, int index)
{
	char sUserId[16];
	char sName[MAX_NAME_LENGTH];
	Menu menu = new Menu(MenuHandler_IncapSurvivor);
	menu.SetTitle("目标玩家");
	menu.AddItem("allplayer", "所有");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && !IsIncapacitated(i))
		{
			FormatEx(sUserId, sizeof(sUserId), "%d", GetClientUserId(i));
			FormatEx(sName, sizeof(sName), "%N", i);
			menu.AddItem(sUserId, sName);
		}
	}
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_IncapSurvivor(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				if (StrEqual(sItem, "allplayer"))
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						IncapCheck(i);
					}
					Action_Othoer(client, 0);
				}
				else
				{
					int iTarget = GetClientOfUserId(StringToInt(sItem));
					if (iTarget && IsClientInGame(iTarget))
					{
						IncapCheck(iTarget);
					}
					IncapSurvivor(client, menu.Selection);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Action_Othoer(client, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

bool IsIncapacitated(int client) 
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0;
}

void IncapCheck(int client)
{
	if (IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsIncapacitated(client))
	{
		ConVar maxIncapacitatedCount = FindConVar("survivor_max_incapacitated_count");
		if (GetEntProp(client, Prop_Send, "m_currentReviveCount") >= maxIncapacitatedCount.IntValue)
		{
			SetEntProp(client, Prop_Send, "m_currentReviveCount", maxIncapacitatedCount.IntValue - 1);
			SetEntProp(client, Prop_Send, "m_isGoingToDie", 0);
			SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", 0);
			StopSound(client, SNDCHAN_STATIC, "player/heartbeatloop.wav");
		}
		IncapPlayer(client);
	}
}

void IncapPlayer(int client) 
{
	SetEntityHealth(client, 1);
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
	SDKHooks_TakeDamage(client, 0, 0, 100.0, DMG_GENERIC);
}

void StripWeapon(int client, int index)
{
	char sUserId[16];
	char sName[MAX_NAME_LENGTH];
	Menu menu = new Menu(MenuHandler_StripWeapon);
	menu.SetTitle("目标玩家");
	menu.AddItem("allplayer", "所有");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			FormatEx(sUserId, sizeof(sUserId), "%d", GetClientUserId(i));
			FormatEx(sName, sizeof(sName), "%N", i);
			menu.AddItem(sUserId, sName);
		}
	}
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_StripWeapon(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				if (StrEqual(sItem, "allplayer"))
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
						{
							DeletePlayerSlotAll(i);
						}
					}
					Action_Othoer(client, 0);
				}
				else
				{
					int iTarget = GetClientOfUserId(StringToInt(sItem));
					if (iTarget && IsClientInGame(iTarget))
					{
						g_iCurrentPage[client] = menu.Selection;
						SlotSlect(client, iTarget);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Action_Othoer(client, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void SlotSlect(int client, int target)
{
	char sUserId[3][16];
	char sUserInfo[32];
	char sClassname[32];
	Menu menu = new Menu(MenuHandler_SlotSlect);
	menu.SetTitle("目标装备");
	
	FormatEx(sUserId[0], sizeof(sUserId[0]), "%d", GetClientUserId(target));
	strcopy(sUserId[1], sizeof(sUserId[1]), "allslot");
	ImplodeStrings(sUserId, 2, "|", sUserInfo, sizeof(sUserInfo));
	menu.AddItem(sUserInfo, "所有装备");
	
	for (int i = 0; i < 5; i++)
	{
		int iWeapon = GetPlayerWeaponSlot(target, i);
		if (iWeapon > MaxClients && IsValidEntity(iWeapon))
		{
			FormatEx(sUserId[1], sizeof(sUserId[1]), "%d", i);
			ImplodeStrings(sUserId, 2, "|", sUserInfo, sizeof(sUserInfo));
			GetEntityClassname(iWeapon, sClassname, sizeof(sClassname));
			menu.AddItem(sUserInfo, sClassname[7]);
		}	
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SlotSlect(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				char sInfo[2][16];
				ExplodeString(sItem, "|", sInfo, 2, 16);
				int iTarget = GetClientOfUserId(StringToInt(sInfo[0]));
				if (iTarget && IsClientInGame(iTarget))
				{
					if (StrEqual(sInfo[1], "allslot"))
					{
						DeletePlayerSlotAll(iTarget);
						StripWeapon(client, g_iCurrentPage[client]);
					}
					else
					{
						DeletePlayerSlot(iTarget, StringToInt(sInfo[1]));
						SlotSlect(client, iTarget);
					}
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				StripWeapon(client, g_iCurrentPage[client]);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void DeletePlayerSlot(int client, int iSlot)
{
	iSlot = GetPlayerWeaponSlot(client, iSlot);
	if (iSlot != -1)
	{
		if (RemovePlayerItem(client, iSlot))
		{
			RemoveEntity(iSlot);
		}
	}
}

void DeletePlayerSlotAll(int client)
{
	for (int i = 0; i < 5; i++)
	{
		DeletePlayerSlot(client, i);
	}
}

void RespawnSurvivor(int client, int index)
{
	char sUserId[16];
	char sName[MAX_NAME_LENGTH];
	Menu menu = new Menu(MenuHandler_RespawnSurvivor);
	menu.SetTitle("目标玩家");
	menu.AddItem("alldead", "所有");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerAlive(i))
		{
			FormatEx(sUserId, sizeof(sUserId), "%d", GetClientUserId(i));
			FormatEx(sName, sizeof(sName), "%N", i);
			menu.AddItem(sUserId, sName);
		}
	}
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_RespawnSurvivor(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				if (StrEqual(sItem, "alldead"))
				{
					for (int i = 1; i <= MaxClients; i++)
					{
						if (IsClientInGame(i) && GetClientTeam(i) == 2 && !IsPlayerAlive(i))
						{
							PatchAddress(true);
							SDKCall(g_hSDK_Call_RoundRespawn, i);
							PatchAddress(false);
							TeleportToSurvivor(i);
						}
					}
					Action_Othoer(client, 0);
				}
				else
				{
					int iTarget = GetClientOfUserId(StringToInt(sItem));
					if (iTarget && IsClientInGame(iTarget))
					{
						PatchAddress(true);
						SDKCall(g_hSDK_Call_RoundRespawn, iTarget);
						PatchAddress(false);
						TeleportToSurvivor(iTarget);
					}
					RespawnSurvivor(client, menu.Selection);
				}
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				Action_Othoer(client, 0);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void TeleportToSurvivor(int client)
{
	int iTarget = GetTeleportTarget(client);
	if (iTarget != -1)
	{
		ForceCrouch(client);

		float vPos[3];
		GetClientAbsOrigin(iTarget, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
	}
	
	CheatCommand(client, "give smg");
	
	char sScriptName[32];
	FormatEx(sScriptName, sizeof(sScriptName), "give %s", g_sMeleeClass[GetRandomInt(0, g_iMeleeClassCount - 1)]);
	CheatCommand(client, sScriptName);
}

int GetTeleportTarget(int client)
{
	int iNormal = 0, iIncap = 0, iHanging = 0;
	int[] iNormalSurvivors = new int[MaxClients];
	int[] iIncapSurvivors = new int[MaxClients];
	int[] iHangingSurvivors = new int[MaxClients];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client && IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated") > 0)
			{
				if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge") > 0)
				{
					iHangingSurvivors[iHanging++] = i;
				}
				else
				{
					iIncapSurvivors[iIncap++] = i;
				}
			}
			else
			{
				iNormalSurvivors[iNormal++] = i;
			}
		}
	}
	
	if (iNormal > 0)
	{
		return iNormalSurvivors[GetRandomInt(0, iNormal - 1)];
	}
	else if (iIncap > 0)
	{
		return iIncapSurvivors[GetRandomInt(0, iIncap - 1)];
	}
	else if (iHanging > 0)
	{
		return iHangingSurvivors[GetRandomInt(0, iHanging - 1)];
	}
	else
	{
		return -1;
	}
}

void FriendlyFire(int client)
{
	Menu menu = new Menu(MenuHandler_FriendlyFire);
	menu.SetTitle("友伤");
	menu.AddItem("999", "恢复默认");
	
	// Define the size of the array explicitly
	#define MAX_STRING_LENGTH 16
	#define NUM_FIRE_FACTORS 11
	#define NUM_DESCRIPTIONS 11

	char fireFactors[NUM_FIRE_FACTORS][MAX_STRING_LENGTH] = {
		"0.0", "0.1", "0.2", "0.3", "0.4", 
		"0.5", "0.6", "0.7", "0.8", "0.9", "1.0"
	};

	char descriptions[NUM_DESCRIPTIONS][MAX_STRING_LENGTH] = {
		"0.0(简单)", "0.1(普通)", "0.2", 
		"0.3(困难)", "0.4", "0.5(专家)", 
		"0.6", "0.7", "0.8", "0.9", "1.0"
	};


	for (int i = 0; i < sizeof(fireFactors); i++)
	{
		menu.AddItem(fireFactors[i], descriptions[i]);
	}
	
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_FriendlyFire(Menu menu, MenuAction action, int client, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char sItem[16];
            if (menu.GetItem(param2, sItem, sizeof(sItem)))
            {
                float percent = StringToFloat(sItem);
                ConVar cvars[4];

                // 在运行时初始化 ConVar 数组
                cvars[0] = FindConVar("survivor_friendly_fire_factor_easy");
                cvars[1] = FindConVar("survivor_friendly_fire_factor_normal");
                cvars[2] = FindConVar("survivor_friendly_fire_factor_hard");
                cvars[3] = FindConVar("survivor_friendly_fire_factor_expert");

                if (StrEqual(sItem, "999"))
                {
                    for (int i = 0; i < sizeof(cvars); i++)
                    {
                        cvars[i].RestoreDefault();
                    }
                }
                else
                {
                    for (int i = 0; i < sizeof(cvars); i++)
                    {
                        cvars[i].SetFloat(percent);
                    }
                }
                Action_Othoer(client, 0);
            }
        }

        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                Action_Othoer(client, 0);
            }
        }

        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}


void TeleportPlayer(int client, int index)
{
	char sUserId[16];
	char sName[MAX_NAME_LENGTH];
	Menu menu = new Menu(MenuHandler_TeleportPlayer);
	menu.SetTitle("传送谁");
	menu.AddItem("allsurvivor", "所有生还者");
	menu.AddItem("allinfected", "所有感染者");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			FormatEx(sUserId, sizeof(sUserId), "%d", GetClientUserId(i));
			FormatEx(sName, sizeof(sName), "%N", i);
			menu.AddItem(sUserId, sName);
		}
	}
	menu.ExitBackButton = true;
	menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_TeleportPlayer(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[16];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				g_iCurrentPage[client] = menu.Selection;
				TeleportTarget(client, sItem);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				TeleportPlayer(client, g_iCurrentPage[client]);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void TeleportTarget(int client, const char[] sTarget)
{
	char sUserId[2][16];
	char sUserInfo[32];
	char sName[MAX_NAME_LENGTH];
	Menu menu = new Menu(MenuHandler_TeleportTarget);
	menu.SetTitle("传送到哪里");
	
	strcopy(sUserId[0], sizeof(sUserId[0]), sTarget);
	strcopy(sUserId[1], sizeof(sUserId[1]), "crh");
	ImplodeStrings(sUserId, 2, "|", sUserInfo, sizeof(sUserInfo));
	menu.AddItem(sUserInfo, "鼠标指针处");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsPlayerAlive(i))
		{
			FormatEx(sUserId[1], sizeof(sUserId[1]), "%d", GetClientUserId(i));
			ImplodeStrings(sUserId, 2, "|", sUserInfo, sizeof(sUserInfo));
			FormatEx(sName, sizeof(sName), "%N", i);
			menu.AddItem(sUserInfo, sName);
		}
	}
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_TeleportTarget(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char sItem[32];
			if (menu.GetItem(param2, sItem, sizeof(sItem)))
			{
				char sInfo[2][16];
				bool bAllowTeleport = false;
				float vOrigin[3];
				ExplodeString(sItem, "|", sInfo, 2, 16);
				
				int iVictim = GetClientOfUserId(StringToInt(sInfo[0]));
				int iTargetTeam = 0;
				
				if (StrEqual(sInfo[0], "allsurvivor"))
				{
					iTargetTeam = 2;
				}
				else if (StrEqual(sInfo[0], "allinfected"))
				{
					iTargetTeam = 3;
				}
				else if (iVictim && IsClientInGame(iVictim))
				{
					iTargetTeam = GetClientTeam(iVictim);
				}

				if (StrEqual(sInfo[1], "crh"))
				{
					bAllowTeleport = GetSpawnEndPoint(client, iTargetTeam, vOrigin);
				}
				else
				{
					int iTarget = GetClientOfUserId(StringToInt(sInfo[1]));
					if (iTarget && IsClientInGame(iTarget))
					{
						GetClientAbsOrigin(iTarget, vOrigin);
						bAllowTeleport = true;
					}
				}

				if (bAllowTeleport)
				{
					if (iVictim)
					{
						ForceCrouch(iVictim);
						TeleportFix(iVictim);
						TeleportEntity(iVictim, vOrigin, NULL_VECTOR, NULL_VECTOR);
					}
					else
					{
						for (int i = 1; i <= MaxClients; i++)
						{
							if (IsClientInGame(i) && GetClientTeam(i) == iTargetTeam && IsPlayerAlive(i))
							{
								ForceCrouch(i);
								TeleportFix(i);
								TeleportEntity(i, vOrigin, NULL_VECTOR, NULL_VECTOR);
							}
						}
					}
				}
				else if (StrEqual(sInfo[1], "crh"))
				{
					PrintToChat(client, "获取准心处位置失败!请重新尝试.");
				}

				TeleportPlayer(client, g_iCurrentPage[client]);
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack)
			{
				TeleportPlayer(client, g_iCurrentPage[client]);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	return 0;
}

void ForceCrouch(int client)
{
    SetEntProp(client, Prop_Send, "m_bDucked", 1);
    SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") | FL_DUCKING);
}

// 获取玩家视角方向的终点坐标用于重生点选择
bool GetSpawnEndPoint(int client, int team, float vSpawnVec[3])
{
    float vEnd[3], vEye[3];
    if (GetDirectionEndPoint(client, vEnd))
    {
        GetClientEyePosition(client, vEye);
        ScaleVectorDirection(vEye, vEnd, 0.1);

        if (GetNonCollideEndPoint(client, team, vEnd, vSpawnVec))
            return true;
    }
    GetClientAbsOrigin(client, vSpawnVec); // 如果所有尝试失败，使用玩家当前坐标
    return true;
}

// 延长给定方向的向量
void ScaleVectorDirection(float vStart[3], float vEnd[3], float fMultiple)
{
    float dir[3];
    SubtractVectors(vEnd, vStart, dir);
    ScaleVector(dir, fMultiple);
    AddVectors(vEnd, dir, vEnd);
}

// 获取客户端视角方向的终点坐标
bool GetDirectionEndPoint(int client, float vEndPos[3])
{
    float vDir[3], vPos[3];
    GetClientEyePosition(client, vPos);
    GetClientEyeAngles(client, vDir);
    
    Handle hTrace = TR_TraceRayFilterEx(vPos, vDir, MASK_PLAYERSOLID, RayType_Infinite, TraceRay_NoPlayers);
    if (hTrace)
    {
        if (TR_DidHit(hTrace))
        {
            TR_GetEndPosition(vEndPos, hTrace);
            delete hTrace;
            return true;
        }
        delete hTrace;
    }
    return false;
}

// 获取不与玩家碰撞的终点位置
bool GetNonCollideEndPoint(int client, int team, float vEnd[3], float vEndNonCol[3], bool bEyeOrigin = true)
{
    float vMin[3], vMax[3], vStart[3];
    if (bEyeOrigin)
    {
        GetClientEyePosition(client, vStart);
        
        if (IsTeamStuckPos(team, vStart))
        {
            float vMiddle[3];
            AddVectors(vStart, vEnd, vMiddle);
            ScaleVector(vMiddle, 0.5);
            vStart = vMiddle;
        }
    }
    else
    {
        GetClientAbsOrigin(client, vStart);
    }

    GetTeamClientSize(team, vMin, vMax);
    
    Handle hTrace = TR_TraceHullFilterEx(vStart, vEnd, vMin, vMax, MASK_PLAYERSOLID, TraceRay_NoPlayers);
    if (hTrace != null)
    {
        if (TR_DidHit(hTrace))
        {
            TR_GetEndPosition(vEndNonCol, hTrace);
            delete hTrace;
            if (bEyeOrigin && IsTeamStuckPos(team, vEndNonCol))
            {
                GetNonCollideEndPoint(client, team, vEnd, vEndNonCol, false);
            }
            return true;
        }
        delete hTrace;
    }
    return false;
}

// 获取团队的玩家大小
void GetTeamClientSize(int team, float vMin[3], float vMax[3])
{
	if (team == 2) {}  // 仅为消除警告而用，无实际逻辑意义
	
    vMin[0] = -16.0; vMin[1] = -16.0; vMin[2] = 0.0;
    vMax[0] = 16.0; vMax[1] = 16.0; vMax[2] = 71.0;
}

// 检查某位置是否适合重生
bool IsTeamStuckPos(int team, float vPos[3], bool bDuck = false)
{
    float vMin[3], vMax[3];
    GetTeamClientSize(team, vMin, vMax);
    
    if (bDuck)
    {
        vMax[2] -= 18.0;
    }

    Handle hTrace = TR_TraceHullFilterEx(vPos, vPos, vMin, vMax, MASK_PLAYERSOLID, TraceRay_NoPlayers);
    if (hTrace)
    {
        bool bHit = TR_DidHit(hTrace);
        delete hTrace;
        return bHit;
    }
    return false;
}

// 过滤掉玩家实体的射线追踪
public bool TraceRay_NoPlayers(int entity, int contentsMask)
{
    return entity > MaxClients;
}

// 修复传送后的状态
void TeleportFix(int client)
{
    if (GetClientTeam(client) != 2)
        return;

    SetEntityMoveType(client, MOVETYPE_WALK);
    SetEntProp(client, Prop_Send, "m_fFlags", GetEntProp(client, Prop_Send, "m_fFlags") & ~FL_FROZEN);

    if (IsHanging(client))
    {
        L4D2_ReviveFromIncap(client);
    }
    else
    {
        int attacker = L4D2_GetInfectedAttacker(client);
        if (attacker > 0 && IsClientInGame(attacker) && IsPlayerAlive(attacker))
        {
            SetEntProp(attacker, Prop_Send, "m_fFlags", GetEntProp(attacker, Prop_Send, "m_fFlags") & ~FL_FROZEN);
            ForcePlayerSuicide(attacker);
        }
    }
}

void L4D2_ReviveFromIncap(int client) 
{
    L4D2_RunScript("GetPlayerFromUserID(%d).ReviveFromIncap()", GetClientUserId(client));
}

bool IsHanging(int client)
{
    return GetEntProp(client, Prop_Send, "m_isHangingFromLedge") > 0;
}

void L4D2_RunScript(const char[] sCode, any ...)
{
    static int iScriptLogic = INVALID_ENT_REFERENCE;
    if (iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
    {
        iScriptLogic = EntIndexToEntRef(CreateEntityByName("logic_script"));
        if (iScriptLogic == INVALID_ENT_REFERENCE || !IsValidEntity(iScriptLogic))
        {
            SetFailState("Could not create 'logic_script'");
        }

        DispatchSpawn(iScriptLogic);
    }

    char sBuffer[512];
    VFormat(sBuffer, sizeof(sBuffer), sCode, 2);
    SetVariantString(sBuffer);
    AcceptEntityInput(iScriptLogic, "RunScriptCode");
}

int L4D2_GetInfectedAttacker(int client)
{
    int attacker;

    attacker = GetEntPropEnt(client, Prop_Send, "m_pummelAttacker");
    if (attacker > 0) return attacker;

    attacker = GetEntPropEnt(client, Prop_Send, "m_carryAttacker");
    if (attacker > 0) return attacker;

    attacker = GetEntPropEnt(client, Prop_Send, "m_pounceAttacker");
    if (attacker > 0) return attacker;

    attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
    if (attacker > 0) return attacker;

    attacker = GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker");
    if (attacker > 0) return attacker;

    return -1;
}

void ForcePanicEvent(int client)
{
    CheatCommand(client, "director_force_panic_event");
    Action_Othoer(client, 0);
}

void KickAllSurvivorBot(int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2)
        {
            KickClient(i);
        }
    }
    Action_Othoer(client, 0);
}

void SlayAllInfected()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 3 && IsPlayerAlive(i))
        {
            ForcePlayerSuicide(i);
        }
    }
}

void SlayAllSurvivor()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
        {
            ForcePlayerSuicide(i);
        }
    }
}

void WarpAllSurvivorsToStartArea()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
        {
            QuickCheat(i, "warp_to_start_area");
        }
    }
}

void WarpAllSurvivorsToCheckpoint()
{
    int iCmdClient = GetAnyClient();
    if (iCmdClient)
    {
        QuickCheat(iCmdClient, "warp_all_survivors_to_checkpoint");
    }
}

int GetAnyClient()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            return i;
        }
    }
    return 0;
}

void QuickCheat(int client, const char[] sCmd)
{
    int flags = GetCommandFlags(sCmd);
    SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s", sCmd);
    SetCommandFlags(sCmd, flags);
}

void Action_TeamSwitch(int client, int index)
{
    char sUserId[16];
    char sInfo[PLATFORM_MAX_PATH];
    Menu menu = new Menu(MenuHandler_TeamSwitch);
    menu.SetTitle("目标玩家");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && !IsFakeClient(i))
        {
            FormatEx(sUserId, sizeof(sUserId), "%d", GetClientUserId(i));
            FormatEx(sInfo, sizeof(sInfo), "%N", i);
            switch(GetClientTeam(i))
            {
                case 1:
                    {
                        if (GetBotOfIdle(i))
                            Format(sInfo, sizeof(sInfo), "闲置 - %s", sInfo);
                        else
                            Format(sInfo, sizeof(sInfo), "观众 - %s", sInfo);
                    }
                case 2:
                    Format(sInfo, sizeof(sInfo), "生还 - %s", sInfo);
                case 3:
                    Format(sInfo, sizeof(sInfo), "感染 - %s", sInfo);
            }
            menu.AddItem(sUserId, sInfo);
        }
    }
    menu.ExitBackButton = true;
    menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_TeamSwitch(Menu menu, MenuAction action, int client, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char sItem[16];
            if (menu.GetItem(param2, sItem, sizeof(sItem)))
            {
                g_iCurrentPage[client] = menu.Selection;

                int iTarget = GetClientOfUserId(StringToInt(sItem));
                if (iTarget && IsClientInGame(iTarget))
                {
                    SwitchPlayerTeam(client, iTarget);
                }
                else
                {
                    PrintToChat(client, "目标玩家不在游戏中");
                }
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                Rygive(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

static const int g_iTargetTeam[4] = {0, 1, 2, 3};
static const char g_sTargetTeam[4][] = {"闲置(仅生还)", "观众", "生还", "感染"};

void SwitchPlayerTeam(int client, int iTarget)
{
    char sUserId[2][16];
    char sUserInfo[32];
    Menu menu = new Menu(MenuHandler_SwitchPlayerTeam);
    menu.SetTitle("目标队伍");
    FormatEx(sUserId[0], sizeof(sUserId[0]), "%d", GetClientUserId(iTarget));

    int iTeam;
    if (!GetBotOfIdle(iTarget))
    {
        iTeam = GetClientTeam(iTarget);
    }

    for (int i = 0; i < 4; i++)
    {
        if (iTeam == i || (iTeam != 2 && i == 0))
            continue;

        IntToString(g_iTargetTeam[i], sUserId[1], sizeof(sUserId[1]));
        ImplodeStrings(sUserId, 2, "|", sUserInfo, sizeof(sUserInfo));
        menu.AddItem(sUserInfo, g_sTargetTeam[i]);
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_SwitchPlayerTeam(Menu menu, MenuAction action, int client, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char sItem[16];
            if (menu.GetItem(param2, sItem, sizeof(sItem)))
            {
                char sInfo[2][16];
                ExplodeString(sItem, "|", sInfo, 2, 16);
                int iTarget = GetClientOfUserId(StringToInt(sInfo[0]));
                if (iTarget && IsClientInGame(iTarget))
                {
                    int iOnTeam;
                    if (!GetBotOfIdle(iTarget))
                    {
                        iOnTeam = GetClientTeam(iTarget);
                    }

                    int iTargetTeam = StringToInt(sInfo[1]);
                    if (iOnTeam != iTargetTeam)
                    {
                        switch (iTargetTeam)
                        {
                            case 0:
                            {
                                if (iOnTeam == 2)
                                {
                                    SDKCall(g_hSDK_Call_GoAwayFromKeyboard, iTarget);
                                }
                                else
                                {
                                    PrintToChat(client, "只有生还者才能进行闲置");
                                }
                            }
                            case 1:
                            {
                                if (iOnTeam == 0)
                                {
                                    SDKCall(g_hSDK_Call_TakeOverBot, iTarget, true);
                                }
                                ChangeClientTeam(iTarget, iTargetTeam);
                            }
                            case 2:
                                ChangeTeamToSurvivor(iTarget, iOnTeam);
                            case 3:
                                ChangeClientTeam(iTarget, iTargetTeam);
                        }
                    }
                    else
                    {
                        PrintToChat(client, "玩家已在目标队伍中");
                    }
                    
                    Action_TeamSwitch(client, g_iCurrentPage[client]);
                }
                else
                {
                    PrintToChat(client, "目标玩家不在游戏中");
                }
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                Action_TeamSwitch(client, g_iCurrentPage[client]);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

void ChangeTeamToSurvivor(int client, int iTeam)
{
    if (GetEntProp(client, Prop_Send, "m_isGhost") == 1)
    {
        SetEntProp(client, Prop_Send, "m_isGhost", 0);
    }

    if (iTeam != 1)
    {
        ChangeClientTeam(client, 1);
    }

    int iBot = GetBotOfIdle(client);
    if (iBot)
    {
        SDKCall(g_hSDK_Call_TakeOverBot, client, true);
        return;
    }
    else
    {
        iBot = GetAnyValidAliveSurvivorBot();
    }

    if (iBot)
    {
        SDKCall(g_hSDK_Call_SetHumanSpec, iBot, client);
        SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
        SDKCall(g_hSDK_Call_TakeOverBot, client, true);
    }
    else
    {
        ChangeClientTeam(client, 2);
    }
}

int GetAnyValidAliveSurvivorBot()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidAliveSurvivorBot(i))
        {
            return i;
        }
    }
    return 0;
}

bool IsValidAliveSurvivorBot(int client)
{
    return IsClientInGame(client) && IsFakeClient(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client) && !IsClientInKickQueue(client) && !HasIdlePlayer(client);
}

int GetBotOfIdle(int client)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == 2 && (GetIdlePlayer(i) == client))
        {
            return i;
        }
    }
    return 0;
}

int GetIdlePlayer(int client)
{
    if (IsPlayerAlive(client))
    {
        return HasIdlePlayer(client);
    }
    return 0;
}

int HasIdlePlayer(int client)
{
    if (HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
    {
        client = GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
        if (client > 0 && IsClientInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == 1)
        {
            return client;
        }
    }
    return 0;
}

void Action_HandlingAPI(int client, int index)
{
    Menu menu = new Menu(MenuHandler_HandlingAPI);
    menu.SetTitle("倍率");

    for (float f = 1.0; f <= 3.5; f += 0.1)
    {
        char buffer[16];
        Format(buffer, sizeof(buffer), "%.1f", f);
        menu.AddItem(buffer, buffer);
    }

    menu.ExitBackButton = true;
    menu.DisplayAt(client, index, MENU_TIME_FOREVER);
}

public int MenuHandler_HandlingAPI(Menu menu, MenuAction action, int client, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char sItem[16];
            if (menu.GetItem(param2, sItem, sizeof(sItem)))
            {
                g_iCurrentPage[client] = menu.Selection;
                WeaponSpeedUp(client, sItem);
            }
        }
        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                Rygive(client);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

void WeaponSpeedUp(int client, const char[] sSpeedUp)
{
    char sUserId[2][16];
    char sUserInfo[32];
    char sName[MAX_NAME_LENGTH];
    Menu menu = new Menu(MenuHandler_WeaponSpeedUp);
    menu.SetTitle("目标玩家");

    strcopy(sUserId[0], sizeof(sUserId[0]), sSpeedUp);
    strcopy(sUserId[1], sizeof(sUserId[1]), "allplayer");
    ImplodeStrings(sUserId, 2, "|", sUserInfo, sizeof(sUserInfo));
    menu.AddItem(sUserInfo, "所有");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            FormatEx(sUserId[1], sizeof(sUserId[1]), "%d", GetClientUserId(i));
            FormatEx(sName, sizeof(sName), "(%.1fx)%N", g_fSpeedUp[i], i);
            ImplodeStrings(sUserId, 2, "|", sUserInfo, sizeof(sUserInfo));
            menu.AddItem(sUserInfo, sName);
        }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_WeaponSpeedUp(Menu menu, MenuAction action, int client, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char sItem[16];
            if (menu.GetItem(param2, sItem, sizeof(sItem)))
            {
                char sInfo[2][16];
                ExplodeString(sItem, "|", sInfo, 2, 16);
                float fSpeedUp = StringToFloat(sInfo[0]);

                if (StrEqual(sInfo[1], "allplayer"))
                {
                    for (int i = 1; i <= MaxClients; i++)
                    {
                        if (IsClientInGame(i))
                        {
                            g_fSpeedUp[i] = fSpeedUp;
                        }
                    }
                    PrintToChat(client, "\x05所有玩家 \x01的武器操纵性已被设置为 \x04%.1fx", fSpeedUp);
                    Rygive(client);
                }
                else
                {
                    int iTarget = GetClientOfUserId(StringToInt(sInfo[1]));
                    if (iTarget && IsClientInGame(iTarget))
                    {
                        g_fSpeedUp[iTarget] = fSpeedUp;
                        PrintToChat(client, "\x05%N \x01的武器操纵性已被设置为 \x04%.1fx", iTarget, fSpeedUp);
                    }
                    else
                    {
                        PrintToChat(client, "目标玩家不在游戏中");
                    }
                    
                    Action_HandlingAPI(client, g_iCurrentPage[client]);
                }
            }
        }

        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                Action_HandlingAPI(client, g_iCurrentPage[client]);
            }
        }

        case MenuAction_End:
            delete menu;
    }
    return 0;
}

void Action_DebugMode(int client)
{
    if (g_bDebug)
    {
        g_aSteamIDs.Clear();
        g_bDebug = false;
        ReplyToCommand(client, "调试模式已关闭.");
    }
    else
    {
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && !IsFakeClient(i))
            {
                char sSteamID[64];
                GetClientAuthId(i, AuthId_Steam2, sSteamID, sizeof(sSteamID));
                g_aSteamIDs.SetValue(sSteamID, true, true);
            }
        }
        
        g_bDebug = true;
        ReplyToCommand(client, "调试模式已开启.");
    }
    
    Rygive(client);
}

void ListAliveSurvivor(int client)
{
    char sUserId[16];
    char sName[MAX_NAME_LENGTH];
    Menu menu = new Menu(MenuHandler_ListAliveSurvivor);
    menu.SetTitle("目标玩家");
    menu.AddItem("allplayer", "所有");

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
        {
            FormatEx(sUserId, sizeof(sUserId), "%d", GetClientUserId(i));
            FormatEx(sName, sizeof(sName), "%N", i);
            menu.AddItem(sUserId, sName);
        }
    }

    menu.ExitBackButton = true;
    menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_ListAliveSurvivor(Menu menu, MenuAction action, int client, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char sItem[16];
            if (menu.GetItem(param2, sItem, sizeof(sItem)))
            {
                if (StrEqual(sItem, "allplayer"))
                {
                    for (int i = 1; i <= MaxClients; i++)
                    {
                        if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
                        {
                            CheatCommand(i, g_sItemName[client]);
                        }
                    }
                }
                else
                {
                    CheatCommand(GetClientOfUserId(StringToInt(sItem)), g_sItemName[client]);
                }

                PageExitBackSwitch(client, g_iFunction[client], g_iCurrentPage[client]);
            }
        }

        case MenuAction_Cancel:
        {
            if (param2 == MenuCancel_ExitBack)
            {
                PageExitBackSwitch(client, g_iFunction[client], g_iCurrentPage[client]);
            }
        }

        case MenuAction_End:
            delete menu;
    }
    return 0;
}

void PageExitBackSwitch(int client, int iFunction, int index)
{
    switch (iFunction)
    {
        case 1:
            Gun_Menu(client, index);
        case 2:
            Melee_Menu(client, index);
        case 3:
            Action_Items(client, index);
    }
}

void ReloadAmmo(int client)
{
    int iWeapon = GetPlayerWeaponSlot(client, 0);
    if (iWeapon > MaxClients && IsValidEntity(iWeapon))
    {
        char sWeapon[32];
        GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));
        if (StrEqual(sWeapon, "weapon_rifle_m60"))
        {
            if (g_iClipSize_RifleM60 <= 0)
            {
                g_iClipSize_RifleM60 = 150;
            }
            SetEntProp(iWeapon, Prop_Send, "m_iClip1", g_iClipSize_RifleM60);
        }
        else if (StrEqual(sWeapon, "weapon_grenade_launcher"))
        {
            if (g_iClipSize_GrenadeLauncher <= 0)
            {
                g_iClipSize_GrenadeLauncher = 1;
            }
            SetEntProp(iWeapon, Prop_Send, "m_iClip1", g_iClipSize_GrenadeLauncher);

            int iAmmo_Max = FindConVar("ammo_grenadelauncher_max").IntValue;
            if (iAmmo_Max <= 0)
            {
                iAmmo_Max = 30;
            }
            SetEntData(client, FindSendPropInfo("CTerrorPlayer", "m_iAmmo") + 68, iAmmo_Max);
        }
    }
}

void CheatCommand(int client, const char[] sCommand)
{
    if (client == 0 || !IsClientInGame(client))
    {
        return;
    }

    char sCmd[32];
    if (SplitString(sCommand, " ", sCmd, sizeof(sCmd)) == -1)
    {
        strcopy(sCmd, sizeof(sCmd), sCommand);
    }

    int bits = GetUserFlagBits(client);
    SetUserFlagBits(client, ADMFLAG_ROOT);
    int flags = GetCommandFlags(sCmd);
    SetCommandFlags(sCmd, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, sCommand);
    SetCommandFlags(sCmd, flags);
    SetUserFlagBits(client, bits);
    
    if (StrEqual(sCmd, "give"))
    {
        if (StrEqual(sCommand[5], "health"))
        {
            SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0); // 防止有虚血时give health会超过100血
        }
        else if (StrEqual(sCommand[5], "ammo"))
        {
            ReloadAmmo(client); // M60和榴弹发射器加子弹
        }
    }
}

void LoadGameData()
{
    char sPath[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, sPath, sizeof(sPath), "gamedata/%s.txt", GAMEDATA);
    
    if (!FileExists(sPath))
    {
        SetFailState("\n==========\nMissing required file: \"%s\".\n==========", sPath);
    }

    GameData hGameData = new GameData(GAMEDATA);
    if (hGameData == null)
    {
        SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);
    }

    PrepareSDKCalls(hGameData);
    RoundRespawnPatch(hGameData);

    delete hGameData;
}

void PrepareSDKCalls(GameData hGameData)
{
    // Prepare SDKCall for RoundRespawn
    PrepareSDKCall(SDKCall_Player, hGameData, "RoundRespawn", g_hSDK_Call_RoundRespawn);

    // Prepare SDKCall for SetHumanSpec
    PrepareSDKCall(SDKCall_Player, hGameData, "SetHumanSpec", g_hSDK_Call_SetHumanSpec, SDKPass_Pointer);

    // Prepare SDKCall for TakeOverBot
    PrepareSDKCall(SDKCall_Player, hGameData, "TakeOverBot", g_hSDK_Call_TakeOverBot, SDKPass_Plain);

    // Prepare SDKCall for GoAwayFromKeyboard
    PrepareSDKCall(SDKCall_Player, hGameData, "CTerrorPlayer::GoAwayFromKeyboard", g_hSDK_Call_GoAwayFromKeyboard, SDKPass_Plain, SDKType_Bool);

    // Infected Attack Survivor Team
    PrepareSDKCall(SDKCall_Entity, hGameData, NAME_InfectedAttackSurvivorTeam, g_hSDK_Call_InfectedAttackSurvivorTeam);

    // Prep bot creation calls
    Address pReplaceWithBot = hGameData.GetAddress("NextBotCreatePlayerBot.jumptable");
    if (pReplaceWithBot != Address_Null && LoadFromAddress(pReplaceWithBot, NumberType_Int8) == 0x68)
    {
        PrepWindowsCreateBotCalls(pReplaceWithBot);
    }
    else
    {
        PrepLinuxCreateBotCalls(hGameData);
    }
}

#define SDKType_None SDKType_PlainOldData  // 或者选择一个合适的类型
void PrepareSDKCall(SDKCallType type, GameData hGameData, const char[] sig, Handle &callHandle, SDKPassMethod passMethod = SDKPass_Plain, SDKType returnType = SDKType_PlainOldData)
{
    StartPrepSDKCall(type);
    if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, sig))
    {
        SetFailState("Failed to find signature: %s", sig);
    }

    if (passMethod != SDKPass_Plain)
    {
        PrepSDKCall_AddParameter(SDKType_CBasePlayer, passMethod);
    }

    if (returnType != SDKType_PlainOldData)
    {
        PrepSDKCall_SetReturnInfo(returnType, passMethod);
    }

    callHandle = EndPrepSDKCall();
    if (callHandle == null)
    {
        SetFailState("Failed to create SDKCall: %s", sig);
    }
}


void RoundRespawnPatch(GameData hGameData)
{
    int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
    if (iOffset == -1)
    {
        SetFailState("Failed to find offset: RoundRespawn_Offset");
    }

    int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
    if (iByteMatch == -1)
    {
        SetFailState("Failed to find byte: RoundRespawn_Byte");
    }

    g_pRespawn = hGameData.GetAddress("RoundRespawn");
    if (!g_pRespawn)
    {
        SetFailState("Failed to find address: RoundRespawn");
    }
    
    g_pResetStatCondition = g_pRespawn + view_as<Address>(iOffset);
    
    int iByteOrigin = LoadFromAddress(g_pResetStatCondition, NumberType_Int8);
    if (iByteOrigin != iByteMatch)
    {
        SetFailState("Failed to load, byte mismatch @ %d (0x%02X != 0x%02X)", iOffset, iByteOrigin, iByteMatch);
    }
}

void PatchAddress(bool bPatch)
{
    static bool bPatched;
    if (!bPatched && bPatch)
    {
        bPatched = true;
        StoreToAddress(g_pResetStatCondition, 0x79, NumberType_Int8);
    }
    else if (bPatched && !bPatch)
    {
        bPatched = false;
        StoreToAddress(g_pResetStatCondition, 0x75, NumberType_Int8);
    }
}

void LoadStringFromAddress(Address pAddr, char[] sBuffer, int iMaxLength)
{
    for (int i = 0; i < iMaxLength; i++)
    {
        char val = LoadFromAddress(pAddr + view_as<Address>(i), NumberType_Int8);
        if (val == 0)
        {
            sBuffer[i] = 0;
            break;
        }
        sBuffer[i] = val;
    }
    sBuffer[iMaxLength - 1] = 0;
}

Handle PrepCreateBotCallFromAddress(StringMap hSiFuncHashMap, const char[] sSIName)
{
    Address pAddr;
    StartPrepSDKCall(SDKCall_Static);
    if (!hSiFuncHashMap.GetValue(sSIName, pAddr) || !PrepSDKCall_SetAddress(pAddr))
    {
        SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", sSIName);
    }
    
    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);

    return EndPrepSDKCall();  
}

void PrepWindowsCreateBotCalls(Address pJumpTableAddr)
{
    StringMap hInfectedHashMap = CreateTrie();

    for (int i = 0; i < 7; i++)
    {
        Address pCaseBase = pJumpTableAddr + view_as<Address>(i * 12);
        Address pSIStringAddr = view_as<Address>(LoadFromAddress(pCaseBase + view_as<Address>(1), NumberType_Int32));
        
        char sSIName[32];
        LoadStringFromAddress(pSIStringAddr, sSIName, sizeof(sSIName));

        Address pFuncRefAddr = pCaseBase + view_as<Address>(6); // 2nd byte of call
        int oFuncRelOffset = LoadFromAddress(pFuncRefAddr, NumberType_Int32);
        Address pCallOffsetBase = pCaseBase + view_as<Address>(10);
        Address pNextBotCreatePlayerBotTAddr = pCallOffsetBase + view_as<Address>(oFuncRelOffset);
        
        PrintToServer("Found NextBotCreatePlayerBot<%s>() @ %08x", sSIName, pNextBotCreatePlayerBotTAddr);
        hInfectedHashMap.SetValue(sSIName, pNextBotCreatePlayerBotTAddr);
    }

    PrepareBotCreationCalls(hInfectedHashMap);
}

void PrepLinuxCreateBotCalls(GameData hGameData)
{
    PrepareBotCreationCall(hGameData, NAME_CreateSmoker, g_hSDK_Call_CreateSmoker);
    PrepareBotCreationCall(hGameData, NAME_CreateBoomer, g_hSDK_Call_CreateBoomer);
    PrepareBotCreationCall(hGameData, NAME_CreateHunter, g_hSDK_Call_CreateHunter);
    PrepareBotCreationCall(hGameData, NAME_CreateSpitter, g_hSDK_Call_CreateSpitter);
    PrepareBotCreationCall(hGameData, NAME_CreateJockey, g_hSDK_Call_CreateJockey);
    PrepareBotCreationCall(hGameData, NAME_CreateCharger, g_hSDK_Call_CreateCharger);
    PrepareBotCreationCall(hGameData, NAME_CreateTank, g_hSDK_Call_CreateTank);
}

void PrepareBotCreationCall(GameData hGameData, const char[] name, Handle &callHandle)
{
    StartPrepSDKCall(SDKCall_Static);
    
    if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, name))
    {
        SetFailState("Failed to find signature: %s", name);
    }

    PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
    PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);

    callHandle = EndPrepSDKCall();
    if (callHandle == null)
    {
        SetFailState("Failed to create SDKCall: %s", name);
    }
}

void PrepareBotCreationCalls(StringMap hInfectedHashMap)
{
    g_hSDK_Call_CreateSmoker = PrepCreateBotCallFromAddress(hInfectedHashMap, "Smoker");
    VerifyCallCreation(g_hSDK_Call_CreateSmoker, NAME_CreateSmoker);

    g_hSDK_Call_CreateBoomer = PrepCreateBotCallFromAddress(hInfectedHashMap, "Boomer");
    VerifyCallCreation(g_hSDK_Call_CreateBoomer, NAME_CreateBoomer);

    g_hSDK_Call_CreateHunter = PrepCreateBotCallFromAddress(hInfectedHashMap, "Hunter");
    VerifyCallCreation(g_hSDK_Call_CreateHunter, NAME_CreateHunter);

    g_hSDK_Call_CreateTank = PrepCreateBotCallFromAddress(hInfectedHashMap, "Tank");
    VerifyCallCreation(g_hSDK_Call_CreateTank, NAME_CreateTank);

    g_hSDK_Call_CreateSpitter = PrepCreateBotCallFromAddress(hInfectedHashMap, "Spitter");
    VerifyCallCreation(g_hSDK_Call_CreateSpitter, NAME_CreateSpitter);

    g_hSDK_Call_CreateJockey = PrepCreateBotCallFromAddress(hInfectedHashMap, "Jockey");
    VerifyCallCreation(g_hSDK_Call_CreateJockey, NAME_CreateJockey);

    g_hSDK_Call_CreateCharger = PrepCreateBotCallFromAddress(hInfectedHashMap, "Charger");
    VerifyCallCreation(g_hSDK_Call_CreateCharger, NAME_CreateCharger);
}

void VerifyCallCreation(Handle callHandle, const char[] name)
{
    if (callHandle == null)
    {
        SetFailState("Cannot initialize %s SDKCall, address lookup failed.", name);
    }
}

// ====================================================================================================
//                  WEAPON HANDLING
// ====================================================================================================
public void WH_OnMeleeSwing(int client, int weapon, float &speedmodifier)
{
    speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnStartThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnReadyingThrow(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnReloadModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnGetRateOfFire(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    switch (weapontype)
    {
        case L4D2WeaponType_Rifle, L4D2WeaponType_RifleSg552, 
             L4D2WeaponType_SMG, L4D2WeaponType_RifleAk47, L4D2WeaponType_SMGMp5, 
             L4D2WeaponType_SMGSilenced, L4D2WeaponType_RifleM60:
        {
            return;
        }
    }

    speedmodifier = SpeedModifier(client, speedmodifier);
}

public void WH_OnDeployModifier(int client, int weapon, L4D2WeaponType weapontype, float &speedmodifier)
{
    speedmodifier = SpeedModifier(client, speedmodifier);
}

float SpeedModifier(int client, float speedmodifier)
{
    if (g_fSpeedUp[client] > 1.0)
    {
        speedmodifier *= g_fSpeedUp[client];
    }
    return speedmodifier;
}

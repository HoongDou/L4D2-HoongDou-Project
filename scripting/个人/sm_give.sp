#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <smlib>
#include <colors>
#define PLUGIN_VERSION "1.0"

#define TEAM_SURVIVOR 2

static const	ASSAULT_RIFLE_OFFSET_IAMMO		= 12;
static const	SMG_OFFSET_IAMMO				= 20;
static const	PUMPSHOTGUN_OFFSET_IAMMO		= 28;
static const	AUTO_SHOTGUN_OFFSET_IAMMO		= 32;
static const	HUNTING_RIFLE_OFFSET_IAMMO		= 36;
static const	MILITARY_SNIPER_OFFSET_IAMMO	= 40;
static const	GRENADE_LAUNCHER_OFFSET_IAMMO	= 68;

static const	SMG_INDEX				= 289;
static const	PUMPSHOTGUN_INDEX		= 288;
static const	PISTOL_MAGNUM_INDEX		= 276;
static const	PISTOL_SINGLE_INDEX		= 292;
static const	PISTOL_DUAL_INDEX		= 291;

new String:g_items[][] = {
	"pistol",
	"pistol_magnum",
	"smg",
	"smg_silenced",
	"shotgun_chrome",
	"pumpshotgun",
	"sniper_scout",
	"sniper_awp",
	"pain_pills",
	"adrenaline"
	};

new g_iMeleeClassCount = 0;

new String:g_sMeleeClass[16][32];

new Handle:g_Cvar_AdminsImmune = INVALID_HANDLE;		// can admins use command at any time?
new Handle:g_hAmmoShotgun;
new Handle:g_hAmmoSmg;
new Handle:g_hAmmoSniper;
new bool:AUTO_AMMO_REFILL = false;
 
public Plugin:myinfo =
{
	name = "sm_give",
	author = "def (user00111)",
	description = "Give yourself items/weapons at round start.",
	version = PLUGIN_VERSION,
	url = "N/A"
};

public OnPluginStart() {
	CreateConVar("sm_give_version", PLUGIN_VERSION, "[L4D2] sm_give", FCVAR_SPONLY | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	
	g_Cvar_AdminsImmune = CreateConVar("sm_give_adminsallowed", "1", "0 = Off | 1 = On -- Admins allowed to use command any time?");
	
	RegConsoleCmd("sm_give", Cmd_SM_Give, "sm_give [item_name] [item_name]");
	RegConsoleCmd("sm_ammo", Cmd_SM_Ammo, "sm_ammo");
	HookEvent("weapon_reload", Event_Weapon_Reload,  EventHookMode_Pre);
	g_hAmmoShotgun = FindConVar("ammo_shotgun_max");
	g_hAmmoSmg = FindConVar("ammo_smg_max");
	g_hAmmoSniper = FindConVar("ammo_sniperrifle_max");
}	

public OnMapStart()
{
	PrecacheModel("models/w_models/v_rif_m60.mdl", true);
	PrecacheModel("models/w_models/weapons/w_m60.mdl", true);
	PrecacheModel("models/v_models/v_m60.mdl", true);
	
	GetMeleeClasses();
}

public Action:Event_Weapon_Reload(Handle:event, const String:name[], bool:dontBroadcast)
{
	decl offsettoadd,currentammo;
	decl String:buffer[64];
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new iAmmoOffset = FindDataMapInfo(client, "m_iAmmo");
	Client_GetActiveWeaponName(client, buffer, 64);
	if(AUTO_AMMO_REFILL){
		if(StrEqual(buffer,"weapon_shotgun_chrome")|| StrEqual(buffer,"weapon_pumpshotgun")){
		offsettoadd = PUMPSHOTGUN_OFFSET_IAMMO;
		currentammo = GetEntData(client, (iAmmoOffset + offsettoadd)); //get current ammo
		if(currentammo <= 16)
		{
			Client_SetWeaponAmmo(client, "weapon_shotgun_chrome", GetConVarInt(g_hAmmoShotgun), -1, -1, -1);
			Client_SetWeaponAmmo(client, "weapon_pumpshotgun", GetConVarInt(g_hAmmoShotgun), -1, -1, -1);
			CPrintToChatAll("{olive}AUTO AMMO REFILL{default}:{red}AUTO REFILLED{default}");
		}
	}
	else if(StrEqual(buffer,"weapon_smg")|| StrEqual(buffer,"weapon_smg_silenced")){
		offsettoadd = SMG_OFFSET_IAMMO;
		currentammo = GetEntData(client, (iAmmoOffset + offsettoadd)); //get current ammo
		if(currentammo <= 100)
		{
			Client_SetWeaponAmmo(client, "weapon_smg", GetConVarInt(g_hAmmoSmg), -1, -1, -1);
			Client_SetWeaponAmmo(client, "weapon_smg_silenced", GetConVarInt(g_hAmmoSmg), -1, -1, -1);
			CPrintToChatAll("[{olive}AUTO AMMO REFILL{default}:{red}AUTO REFILLED{default}");
		}
	}
	else if(StrEqual(buffer,"weapon_sniper_scout")|| StrEqual(buffer,"weapon_sniper_awp")){
		offsettoadd = MILITARY_SNIPER_OFFSET_IAMMO;
		currentammo = GetEntData(client, (iAmmoOffset + offsettoadd)); //get current ammo
		if(currentammo <= 20)
		{
			Client_SetWeaponAmmo(client, "weapon_sniper_scout", GetConVarInt(g_hAmmoSniper), -1, -1, -1);
			Client_SetWeaponAmmo(client, "weapon_sniper_awp", GetConVarInt(g_hAmmoSniper), -1, -1, -1);
			CPrintToChatAll("[{olive}AUTO AMMO REFILL{default}:{red}AUTO REFILLED{default}");
		}
	}
	else{

	}
	}
}

public Action:Cmd_SM_Ammo(client, argCount)
{
	if(AUTO_AMMO_REFILL){
	AUTO_AMMO_REFILL = false;
	CPrintToChatAll("{olive}AUTO AMMO REFILL{default} : {red}OFF{default}");
	}
	else
	{
	AUTO_AMMO_REFILL = true;
	CPrintToChatAll("{olive}AUTO AMMO REFILL{default} : {red}ON{default}");
	}
}

public Action:Cmd_SM_Give(client, argCount)
{	
	if (!IsValidSurvivor(client))
	{
		return Plugin_Handled;
	}
	
	
	if (argCount < 1)
	{
		DisplayGiveMenu(client);
		return Plugin_Handled;
	}

	new bool:found = false;
	new i;
	
	new flags = GetCommandFlags("give");
	SetCommandFlags("give", flags & ~FCVAR_CHEAT);
		
	for (new argnum = 1; argnum <= argCount; argnum++)
	{	
		decl String:arg[64], String:item[64];
		GetCmdArg(argnum, arg, sizeof(arg));
		
		if (found != false) found = false; // reset
		
		if (StrEqual(arg, "bile", false) ||
				StrEqual(arg, "puke", false)) {
			strcopy(item, sizeof(item), "vomitjar");
			found = true;
		}
		
		if (!found)
		{
			for (i = 0; i < g_iMeleeClassCount; i++)
			{
				if (StrContains(g_sMeleeClass[i], arg, false) > -1)
				{
					strcopy(item, sizeof(item), g_sMeleeClass[i]);
					found = true;
					break;
				}
			}
		}
		
		if (!found)
		{
			for (i = 0; i < sizeof(g_items); i++)
			{ 
				if (StrContains(g_items[i], arg, false) != -1) {
					strcopy(item, sizeof(item), g_items[i]);
					found = true;
					break;
				}	 
			}
		}

		if (!found) {
			strcopy(item, sizeof(item), arg);		
		}	 
		FakeClientCommand(client, "give %s", item);
	}
	SetCommandFlags("give", flags|FCVAR_CHEAT);
	return Plugin_Handled;		
}

DisplayGiveMenu(client, time=MENU_TIME_FOREVER) 
{ 
	new Handle:menu = CreateMenu(GiveMenuHandler); 
	SetMenuTitle(menu, "Give Menu");
	AddMenuItem(menu, "1", "Items");
	AddMenuItem(menu, "2", "Melees"); 
	SetMenuExitButton(menu, true); 
	DisplayMenu(menu, client, time);
}

DisplayMeleeMenu(client, time=MENU_TIME_FOREVER)
{ 
	new Handle:menu = CreateMenu(MeleeMenuHandler); 
	SetMenuTitle(menu, "Melees: %d", g_iMeleeClassCount);
	for (new i = 0; i < g_iMeleeClassCount; i++)
	{
		AddMenuItem(menu, "", g_sMeleeClass[i]);
	}		
	SetMenuExitButton(menu, true); 
	DisplayMenu(menu, client, time);
}

DisplayItemsMenu(client, time=MENU_TIME_FOREVER) 
{ 
	new Handle:menu = CreateMenu(ItemsMenuHandler); 
	SetMenuTitle(menu, "Choose a item:");
	for (new i = 0; i < sizeof(g_items); i++)
	{ 
		AddMenuItem(menu, "", g_items[i]);
	}
	SetMenuExitButton(menu, true); 
	DisplayMenu(menu, client, time); 
}

public ItemsMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
	if (action == MenuAction_Select) { 
		decl String:weapon[64];
		Format(weapon, sizeof(weapon), "weapon_%s", g_items[itemNum]);
		new entity = GivePlayerItem(client, weapon);
		if (entity != -1) {
			EquipPlayerWeapon(client, entity);
		}
		if(itemNum == 4|| itemNum == 5)
		{
			Client_SetWeaponAmmo(client, weapon, GetConVarInt(g_hAmmoShotgun), -1, -1, -1);
		}
		if(itemNum == 2 || itemNum == 3)
		{
			Client_SetWeaponAmmo(client, weapon, GetConVarInt(g_hAmmoSmg), -1, -1, -1);
		}
		if(itemNum == 6|| itemNum == 7)
		{
			Client_SetWeaponAmmo(client, weapon, GetConVarInt(g_hAmmoSniper), -1, -1, -1);
		}
		DisplayMenu(menu, client, 60);
	}
	else if (action == MenuAction_End) {
		//CloseHandle(menu);
	}
}

public MeleeMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{
	if (action == MenuAction_Select) { 
		new melee = CreateEntityByName("weapon_melee");
		DispatchKeyValue(melee, "melee_script_name", g_sMeleeClass[itemNum]);
		DispatchSpawn(melee);
		decl String:modelname[256];
		GetEntPropString(melee, Prop_Data, "m_ModelName", modelname, sizeof(modelname));
		if (StrContains(modelname, "claw", false) == -1) // hunter claw bug
		{
			new Float:currentPos[3];
			GetClientAbsOrigin(client, currentPos);
			TeleportEntity(melee, currentPos, NULL_VECTOR, NULL_VECTOR);
			EquipPlayerWeapon(client, melee);
		}
		else { // can't spawn melee
			RemoveEdict(melee);
		}
		DisplayGiveMenu(client, 60);
	}
	else if (action == MenuAction_End) {
		//CloseHandle(menu);
	}
}

public GiveMenuHandler(Handle:menu, MenuAction:action, client, itemNum) 
{ 
	if (action == MenuAction_Select) {
		switch (itemNum)
		{
			 case 0: DisplayItemsMenu(client);
			 case 1: DisplayMeleeMenu(client);
		}
	}
	else if (action == MenuAction_End) {
		//CloseHandle(menu);
	}
}
		
bool:IsAdmin(client)
{
	new AdminId:admin = GetUserAdmin(client);

	if (admin == INVALID_ADMIN_ID)
		return false;

	return true;
}

bool:IsValidSurvivor(client)
{
	if (client && IsClientInGame(client)) {
		if (GetClientTeam(client) == TEAM_SURVIVOR) {
			if (IsPlayerAlive(client)) {
				return true;
			}
		}
	}
	return false;			 
}

bool:L4D_HasAnySurvivorLeftSafeArea()
{
		new entity = FindEntityByClassname(-1, "terror_player_manager");

		if (entity == -1)
		{
				return false;
		}

		return bool:GetEntProp(entity, Prop_Send, "m_hasAnySurvivorLeftSafeArea", 1);
}

stock GetMeleeClasses()
{
	new MeleeStringTable = FindStringTable( "MeleeWeapons" );
	g_iMeleeClassCount = GetStringTableNumStrings( MeleeStringTable );
	
	for( new i = 0; i < g_iMeleeClassCount; i++ )
	{
		ReadStringTable( MeleeStringTable, i, g_sMeleeClass[i], 32 );
	}	
}
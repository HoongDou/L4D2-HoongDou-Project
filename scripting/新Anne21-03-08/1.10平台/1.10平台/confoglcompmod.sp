#pragma semicolon 1

#if defined(AUTOVERSION)
#include "version.inc"
#else
#define PLUGIN_VERSION	"AnneHappy 5.0"
#endif

#if !defined(DEBUG_ALL)
#define DEBUG_ALL 	0
#endif

#include <sourcemod>
#include <sdktools>
#include <socket>
#include <sdkhooks>
#include <left4dhooks>
#include "includes/constants.sp"
#include "includes/functions.sp"
#include "includes/debug.sp"
#include "includes/survivorindex.sp"
#include "includes/configs.sp"
#include "includes/customtags.inc"
#include "modules/MapInfo.sp"
#include "modules/WeaponInformation.sp"
#include "modules/ReqMatch.sp"
#include "modules/CvarSettings.sp"
#include "modules/GhostTank.sp"
#include "modules/UnprohibitBosses.sp"
#include "modules/EntityRemover.sp"
#include "modules/FinaleSpawn.sp"
#include "modules/BossSpawning.sp"
#include "modules/l4dt_forwards.sp"
#include "modules/ClientSettings.sp"
#include "modules/ItemTracking.sp"

public Plugin:myinfo = 
{
	name = "Confogl's Competitive Mod",
	author = "Confogl Team",
	description = "A competitive mod for L4D2",
	version = PLUGIN_VERSION,
	url = "http://confogl.googlecode.com/"
}

public OnPluginStart()
{
	Debug_OnModuleStart();
	Configs_OnModuleStart();
	MI_OnModuleStart();
	SI_OnModuleStart();
	WI_OnModuleStart();
	RM_OnModuleStart();
	CVS_OnModuleStart();
	ER_OnModuleStart();
	GT_OnModuleStart();
	UB_OnModuleStart();
	FS_OnModuleStart();
	BS_OnModuleStart();
	CLS_OnModuleStart();
	IT_OnModuleStart();
	
	AddCustomServerTag("confogl", true);
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RM_APL();
	Configs_APL();
	MI_APL();
	RegPluginLibrary("confogl");
}

public OnPluginEnd()
{
	CVS_OnModuleEnd();
	ER_OnModuleEnd();
	//WS_OnModuleEnd();
	RemoveCustomServerTag("confogl");
}

public OnMapStart()
{
	MI_OnMapStart();
	RM_OnMapStart();
	BS_OnMapStart();
	IT_OnMapStart();
}

public OnMapEnd()
{
	MI_OnMapEnd();
	WI_OnMapEnd();
	//WS_OnMapEnd();
}

public OnConfigsExecuted()
{
	CVS_OnConfigsExecuted();
}


public OnClientPutInServer(client)
{
	RM_OnClientPutInServer();
}
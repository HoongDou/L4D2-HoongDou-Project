#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#pragma semicolon 1

#define L4D2 Spitter Supergirl
#define PLUGIN_VERSION "1.5"

#define ZOMBIECLASS_SPITTER 4


// =================================
// Sticky Goo
// =================================

//Bools
new bool:isStickyGoo = false;
new bool:isStickyGooJump = false;

//Handles
new Handle:cvarStickyGoo;
new Handle:cvarStickyGooDuration;
new Handle:cvarStickyGooSpeed;
new Handle:cvarStickyGooJump;
new Handle:cvarStickyGooTimer[MAXPLAYERS + 1] = INVALID_HANDLE;
new Handle:cvarAcidDelay[MAXPLAYERS+1] = INVALID_HANDLE;

new stickygoo[MAXPLAYERS+1];
static laggedMovementOffset = 0;


// ===========================================
// Generic Setup
// ===========================================

static const String:GAMEDATA_FILENAME[] = "l4d2_viciousplugins";

//Handles
new Handle:PluginStartTimer = INVALID_HANDLE;
//new Handle:sdkCallDetonateAcid = INVALID_HANDLE;
//new Handle:sdkCallFling = INVALID_HANDLE;
//new Handle:sdkCallVomitOnPlayer = INVALID_HANDLE;
//new Handle:ConfigFile = INVALID_HANDLE;
new g_iAbilityO = -1;
new g_iNextActO = -1;

// ===========================================
// Plugin Info
// ===========================================

public Plugin:myinfo = 
{
    name = "[L4D2] Spitter Supergirl",
    author = "Mortiegama",
    description = "Adds a host of abilities to the Spitter to add Supergirl like powers.",
    version = PLUGIN_VERSION,
    url = "https://forums.alliedmods.net/showthread.php?t=122802"
}

// ===========================================
// Plugin Start
// ===========================================

public OnPluginStart()
{
	CreateConVar("l4d_ssg_version", PLUGIN_VERSION, "Spitter Supergirl Version", FCVAR_NONE|FCVAR_SPONLY|FCVAR_DONTRECORD|FCVAR_NOTIFY);


	// ======================================
	// Spitter Ability: Sticky Goo
	// ======================================
	cvarStickyGoo = CreateConVar("l4d_ssg_stickygoo", "1", "Enables Sticky Goo ability: Any Survivor standing inside a pool of Spit will be stuck in the goo and find it harder to move out quickly. (Def 1)", FCVAR_NONE);
	cvarStickyGooJump = CreateConVar("l4d_ssg_stickygoojump", "0", "Prevents the Survivor from jumping while speed is reduced. (Def 1)", FCVAR_NONE);
	cvarStickyGooDuration = CreateConVar("l4d_ssg_stickygooduration", "3", "For how long after exiting the Sticky Goo will a Survivor be slowed. (Def 3)", FCVAR_NONE);
	cvarStickyGooSpeed = CreateConVar("l4d_ssg_stickygoospeed", "0.5", "Speed reduction to Survivor caused by the Sticky Goo. (Def 0.5)", FCVAR_NONE);


	// ======================================
	// Hook Events
	// ======================================
	//HookEvent("spit_burst", Event_SpitBurst);
	//HookEvent("player_spawn", Event_PlayerSpawn);
	
	// ======================================
	// General Setup
	// ======================================
	laggedMovementOffset = FindSendPropInfo("CTerrorPlayer", "m_flLaggedMovementValue");
	g_iNextActO			=	HasEntProp("CBaseAbility","m_nextActivationTimer");
	g_iAbilityO			=	FindSendPropInfo("CTerrorPlayer","m_customAbility");
	
	//AutoExecConfig(true, "plugin.L4D2.Supergirl");
	PluginStartTimer = CreateTimer(3.0, OnPluginStart_Delayed);
	
	//ConfigFile = LoadGameConfigFile(GAMEDATA_FILENAME);
	
	// ======================================
	// SDK Calls
	// ======================================
	/*
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CSpitterProjectile_Detonate");
	sdkCallDetonateAcid = EndPrepSDKCall();
	if(sdkCallDetonateAcid == INVALID_HANDLE)
	{
		LogError("Could not prep the Detonate Acid function");
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_OnVomitedUpon");
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	sdkCallVomitOnPlayer = EndPrepSDKCall();
	
	if (sdkCallVomitOnPlayer == INVALID_HANDLE)
	{
		SetFailState("Cant initialize OnVomitedUpon SDKCall");
		return;
	}
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	
	if (sdkCallFling == INVALID_HANDLE)
	{
		SetFailState("Cant initialize Fling SDKCall");
		return;
	}
	
	CloseHandle(ConfigFile);
}

*/

// ===========================================
// Plugin Start Delayed
// ===========================================

public Action:OnPluginStart_Delayed(Handle:timer)
{
	if (GetConVarInt(cvarStickyGoo))
	{
		isStickyGoo = true;
	}
	
	if (GetConVarInt(cvarStickyGooJump))
	{
		isStickyGooJump = true;
	}
	
	if(PluginStartTimer != INVALID_HANDLE)
	{
 		KillTimer(PluginStartTimer);
		PluginStartTimer = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}




// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================           SPITTER            =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

// ===========================================
// Spitter Setup Events
// ===========================================

public OnClientPostAdminCheck(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, 
	);
}


public Action:OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	if (IsValidEntity(inflictor) && IsValidClient(victim) && GetClientTeam(victim) == 2)
	{
		decl String:classname[56];
		decl String:weapon[64];
		GetEdictClassname(inflictor, classname, sizeof(classname));
		GetClientWeapon(attacker, weapon, sizeof(weapon));
		
		if (StrEqual(classname, "insect_swarm"))
		{
			// =================================
			// Spitter Ability: Sticky Goo
			// =================================
			if (isStickyGoo)
			{
				SpitterAbility_StickyGoo(victim);
			}
			
			cvarAcidDelay[victim] = CreateTimer(1.0, Timer_AcidDelay, victim);
			aciddelay[victim] = true;
		}
	}
}

public Action:Timer_AcidDelay(Handle:timer, any:victim)
{
	aciddelay[victim] = false;
	
	if (cvarAcidDelay[victim] != INVALID_HANDLE)
	{
		KillTimer(cvarAcidDelay[victim]);
		cvarAcidDelay[victim] = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}


// ===========================================
// Spitter Ability: Sticky Goo
// ===========================================
// Description: Any Survivor standing inside a pool of Spit will be stuck in the goo and find it harder to move out quickly.

public SpitterAbility_StickyGoo(victim)
{
	if (stickygoo[victim] <= 0)
	{
		stickygoo[victim] = (GetConVarInt(cvarStickyGooDuration));
		cvarStickyGooTimer[victim] = CreateTimer(1.0, Timer_StickyGoo, victim, TIMER_REPEAT);
		SetEntDataFloat(victim, laggedMovementOffset, GetConVarFloat(cvarStickyGooSpeed), true);

		if (isStickyGooJump)
		{
				SetEntityGravity(victim, 5.0);
		}
			
		PrintHintText(victim, "Standing in the spit is slowing you down!");
	}
			
	if (stickygoo[victim] > 0 && !aciddelay[victim])
	{
		stickygoo[victim]++;
	}
}

public Action:Timer_StickyGoo(Handle:timer, any:victim) 
{
	if (IsValidClient(victim))
	{
		if(stickygoo[victim] <= 0)
		{
			SetEntDataFloat(victim, laggedMovementOffset, 1.0, true); //sets the survivors speed back to normal
			SetEntityGravity(victim, 1.0);
			PrintHintText(victim, "The spit is wearing off!");
			
			if (cvarStickyGooTimer[victim] != INVALID_HANDLE)
				{
					KillTimer(cvarStickyGooTimer[victim]);
					cvarStickyGooTimer[victim] = INVALID_HANDLE;
				}
				
			return Plugin_Stop;
		}

		if(stickygoo[victim] > 0) 
		{
			stickygoo[victim] -= 1;
		}
	}
	
	return Plugin_Continue;
}


// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================        GENERIC CALLS         =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

public Action:DamageHook(victim, attacker, damage)
{
	decl Float:victimPos[3], String:strDamage[16], String:strDamageTarget[16];
			
	GetClientEyePosition(victim, victimPos);
	IntToString(damage, strDamage, sizeof(strDamage));
	Format(strDamageTarget, sizeof(strDamageTarget), "hurtme%d", victim);
	
	new entPointHurt = CreateEntityByName("point_hurt");
	if(!entPointHurt) return;

	// Config, create point_hurt
	DispatchKeyValue(victim, "targetname", strDamageTarget);
	DispatchKeyValue(entPointHurt, "DamageTarget", strDamageTarget);
	DispatchKeyValue(entPointHurt, "Damage", strDamage);
	DispatchKeyValue(entPointHurt, "DamageType", "0"); // DMG_GENERIC
	DispatchSpawn(entPointHurt);
	
	// Teleport, activate point_hurt
	TeleportEntity(entPointHurt, victimPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(entPointHurt, "Hurt", (attacker && attacker < MaxClients && IsClientInGame(attacker)) ? attacker : -1);
	
	// Config, delete point_hurt
	DispatchKeyValue(entPointHurt, "classname", "point_hurt");
	DispatchKeyValue(victim, "targetname", "null");
	RemoveEdict(entPointHurt);
}




// ====================================================================================================================
// ===========================================                              =========================================== 
// ===========================================          BOOL CALLS          =========================================== 
// ===========================================                              =========================================== 
// ====================================================================================================================

public IsValidClient(client)
{
	if (client <= 0)
		return false;
		
	if (client > MaxClients)
		return false;
		
	if (!IsClientInGame(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	return true;
}

public IsValidDeadClient(client)
{
	if (client <= 0)
		return false;
		
	if (client > MaxClients)
		return false;
		
	if (!IsClientInGame(client))
		return false;
		
	if (IsPlayerAlive(client))
		return false;

	return true;
}

public IsValidSpitter(client)
{
	if (IsValidClient(client) && GetClientTeam(client) == 3)
	{
		new class = GetEntProp(client, Prop_Send, "m_zombieClass");
		
		if (class == ZOMBIECLASS_SPITTER)
			return true;
		
		return false;
	}
	
	return false;
}

public IsPlayerGhost(client)
{
	if (IsValidClient(client))
	{
		if (GetEntProp(client, Prop_Send, "m_isGhost")) return true;
		else return false;
	}
	else return false;
}
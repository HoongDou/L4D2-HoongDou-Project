//特感传送
#pragma semicolon 1
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <l4d2util>
#include <l4d2_direct>
#include <smlib>
#include <left4downtown>
#include <sourcemod>
#include <sdktools>
#define DEBUG 		false
#define MIN(%0,%1) (((%0) < (%1)) ? (%0) : (%1))
#define TRACE_TOLERANCE 150.0
//new Handle:g_hDiscardRange;
new Handle:g_hCheckinterval;
new Handle:g_hTeleRangeMax;
new Handle:g_hTeleRangeMin;
new Handle:g_hTeleLimit;
new si2tele[6] = {-1, -1, -1, -1, -1, -1};
new sitele2[3] = {-1, -1, -1};
new bool:g_bRoundAlive;
new Float:g_fCheckinterval;
new g_iSsitpLimit;
static const String:CLASSNAME_INFECTED[]			= "infected";
static const String:CLASSNAME_WITCH[]				= "witch";
static const String:CLASSNAME_PHYSPROPS[]			= "prop_physics";
enum AimTarget
{
        AimTarget_Eye,
        AimTarget_Body,
        AimTarget_Chest
};
public OnPluginStart()
{
	//g_hDiscardRange  	= CreateConVar("ssitp_discard_range", 	"800",	"Discard range");
	g_hTeleRangeMax 	= CreateConVar("ssitp_tp_range_max", 	"500", 	"teleport max range");
	g_hTeleRangeMin 	= CreateConVar("ssitp_tp_range_min", 	"150", 	"teleport min range");
	g_hCheckinterval 	= CreateConVar("ssitp_check_interval", 	"2.0",	"time to check noob si", FCVAR_PLUGIN, true, 1.0);
	g_hTeleLimit		= CreateConVar("ssitp_tp_limit",   		"4", 	"Limit per teleport.", FCVAR_PLUGIN, true, 1.0, true, 6.0);
	HookEvent("round_start", 	Event_RoundStart, 	EventHookMode_PostNoCopy);
	HookEvent("round_end", 		Event_RoundEnd, 	EventHookMode_PostNoCopy);
	//HookEvent("player_spawn", OnPlayerSpawnPre, EventHookMode_Pre);
	g_bRoundAlive 		= false;
	g_fCheckinterval 	= GetConVarFloat(g_hCheckinterval);
	g_iSsitpLimit		= GetConVarInt(g_hTeleLimit);
}
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundAlive = false;
}
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundAlive = false;
}
public Action:L4D_OnFirstSurvivorLeftSafeArea(client) 
{
	g_bRoundAlive = true;
	g_fCheckinterval = GetConVarFloat(g_hCheckinterval);
	g_iSsitpLimit	= GetConVarInt(g_hTeleLimit);
	CreateTimer(g_fCheckinterval,Timer_CheckNoobSi, _, TIMER_REPEAT);
}
public Action:Timer_CheckNoobSi(Handle:timer)
{
	new index1 = FindSItele2();
	new index2 = FindSI2Tele();
	
	if(index1 != 0 && index2 != 0)
	{
		index2 = MIN(index2, index1*g_iSsitpLimit);
		for(new i=0; i<index2; i++)
		{	
			TeleOne2One(si2tele[i],sitele2[i%index1]);
		}
	}
	if(!g_bRoundAlive)
		return Plugin_Stop;
	return Plugin_Continue;
}
//传送到近的地方
bool: CanBeTP(client)
{
	if (!IsClientInGame(client) || !IsFakeClient(client))return false;
	if (GetClientTeam(client) != 3 || !IsPlayerAlive(client))return false;
	if (L4D2_Infected:GetInfectedClass(client) ==  L4D2Infected_Tank )return false;
	if (L4D2_Infected:GetInfectedClass(client) ==  L4D2Infected_Smoker )return false;
	if(IsInfectedGhost(client))return false; 
	if(IsVisibleToSurvivors(client))return false;
	return true;
}
//传送位置的条件
bool: CanTP2(client)
{
	if(!IsClientInGame(client))return false;
	if(GetClientTeam(client) != 3 || !IsPlayerAlive(client))return false;
	if(IsInfectedGhost(client))return false; 
	if(IsVisibleToSurvivors(client))return false;
	return true;
}
//传送位置（不变）
stock FindSItele2()
{
	new index = 0;
	for(new i = 1; i<=MaxClients; i++)
	{
		if( index < 3 && CanTP2(i) && !Far(i) && !Close(i))
			sitele2[index++] = i;
	}
	return index;
}
//传送到近的地方
stock FindSI2Tele()
{
	new index = 0;
	for(new i = 1; i<=MaxClients; i++)
	{
		if(index < 6 && CanBeTP(i) && TooFar(i))
			si2tele[index++] = i;
	}
	return index;
}

//距离过远
bool:TooFar(client)
{
	decl Float:fInfLocation[3], Float:fSurvLocation[3], Float:fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	//new Discard_range = GetConVarInt(g_hDiscardRange);
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			new index = i;
			if (!IsPlayerAlive(index)) continue;
			GetClientAbsOrigin(index, fSurvLocation);
		
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
		
			if (GetVectorLength(fVector) <= 500)			
			return false;
		}
	}
	return true;
}

//传送允许的范围
bool:Far(client)
{
	decl Float:fInfLocation[3], Float:fSurvLocation[3], Float:fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	new maxRange = GetConVarInt(g_hTeleRangeMax);
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && !IsIncap(i) && !IsPinned(i))
		{
			new index = i;
			if (!IsPlayerAlive(index)) continue;
			GetClientAbsOrigin(index, fSurvLocation);
		
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
		
			if (GetVectorLength(fVector) < maxRange) return false;
		}
	}
	return true;
}
//传送不允许的范围
bool:Close(client)
{
	decl Float:fInfLocation[3], Float:fSurvLocation[3], Float:fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	new minRange = GetConVarInt(g_hTeleRangeMin);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			new index = i;
			if (!IsPlayerAlive(index)) continue;
			GetClientAbsOrigin(index, fSurvLocation);
		
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
		
			if (GetVectorLength(fVector) < minRange) return true;
		}
		
	}
	return false;
}
TeleOne2One(client1, client2)
{	
	new bool:bHasSight1 = bool:GetEntProp(client1, Prop_Send, "m_hasVisibleThreats"); //Line of sight to survivors
	new bool:bHasSight2 = bool:GetEntProp(client2, Prop_Send, "m_hasVisibleThreats"); //Line of sight to survivors
	if(!(GetEntityFlags(client2) & FL_ONGROUND) || bHasSight1 || bHasSight2)
	return;
	decl Float:fOwnerOrigin[3];
	GetEntPropVector(client2, Prop_Send, "m_vecOrigin", fOwnerOrigin);
	TeleportEntity(client1, fOwnerOrigin, NULL_VECTOR, NULL_VECTOR);
}
stock bool:IsVisibleToSurvivors(entity)
{
	new iSurv;

	for (new i = 1; i <= MaxClients && iSurv < 5; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			iSurv++;
			if (IsPlayerAlive(i) && IsVisibleTo(i, entity))
			{
				return true;
			}
		}
	}

	return false;
}

stock bool:IsVisibleTo(client, entity) // 检查实体是否对客户端可见
{
	decl Float:vAngles[3], Float:vOrigin[3], Float:vEnt[3], Float:vLookAt[3];
	
	GetClientEyePosition(client,vOrigin); // 同时获得玩家和僵尸的位置
	
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEnt);
	
	MakeVectorFromPoints(vOrigin, vEnt, vLookAt); // 计算从玩家到僵尸的向量
	
	GetVectorAngles(vLookAt, vAngles); //从矢量获取跟踪角度
	
	//执行跟踪
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter);
	
	new bool:isVisible = false;
	if (TR_DidHit(trace))
	{
		decl Float:vStart[3];
		TR_GetEndPosition(vStart, trace); // 检索跟踪终结点
		
		if ((GetVectorDistance(vOrigin, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(vOrigin, vEnt))
		{
			isVisible = true; // 如果跟踪光线长度加上公差等于或大于绝对距离，则会击中目标僵尸
		}
	}
	/*
	else
	{
		//Debug=Uprint（“僵尸设计故障：玩家-僵尸痕迹没有击中任何东西，WTF”）；
		isVisible = true;
	}
	*/
	CloseHandle(trace);
	return isVisible;
}

public bool:TraceFilter(entity, contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity)) // 不要让世界、玩家或无效实体受到打击
	{
		return false;
	}
	decl String:class[128];
	GetEdictClassname(entity, class, sizeof(class)); // 也不可能是僵尸或女巫，或是物理对象（=windows）
	if (StrEqual(class, CLASSNAME_INFECTED, .caseSensitive = false)
	|| StrEqual(class, CLASSNAME_WITCH, .caseSensitive = false) 
	|| StrEqual(class, CLASSNAME_PHYSPROPS, .caseSensitive = false))
	{
		return false;
	}
	
	return true;
}
bool:IsIncap(client) 
{
	new bool:bIsIncapped = false;
	if ( IsSurvivor(client) ) 
	{
		if (GetEntProp(client, Prop_Send, "m_isIncapacitated") > 0) bIsIncapped = true;
		if (!IsPlayerAlive(client)) bIsIncapped = true;
	}
	return bIsIncapped;
}
bool:IsPinned(client) 
{
	new bool:bIsPinned = false;
	if (IsSurvivor(client)) 
	{
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}
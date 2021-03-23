  
/******************************************************************
*
* v0.1 ~ v1.2 by Visor
* ------------------------
* ------- Details: -------
* ------------------------
* > Creates a timer that runs checks to prevent Survivors from baiting attacks (Which is extremely boring)
* - Keeps track of Readyup, Event Hordes, Tanks, and Pauses to prevent sending in hordes unfairly.
*
* v1.3 by Sir (pointer to hordeDelayChecks by devilesk)
* ------------------------
* ------- Details: -------
* ------------------------
* - Now resets internal "hordeDelayChecks" on Round Live to prevent teams from suddenly getting a horde shortly after the round goes live. (Timer wouldn't even be visible at the top)
* - Now also resets saved "baiting" progress that didn't get reset after Event Hordes / Tank Spawns were triggered (Although, it'd be very unlikely that no SI would go in while these were active)
* - Fixed the Timer from showing up on the top while Tank was alive and SI just weren't attacking (to reset the timer) this was only a visual thing though, as the plugin already didn't spawn in horde when a Tank was up.
*
******************************************************************/

#pragma semicolon 1

#include <sourcemod>
#include <left4dhooks>
#include <sdkhooks>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#define DEBUG 0

enum L4D2SI 
{
    ZC_None,
    ZC_Smoker,
    ZC_Boomer,
    ZC_Hunter,
    ZC_Spitter,
    ZC_Jockey,
    ZC_Charger,
    ZC_Witch,
    ZC_Tank,
	ZC_InvalidTeam
};

new Handle:hCvarTimerStartDelay;
new Handle:hCvarHordeCountdown;
new Handle:hCvarMinProgressThreshold;

new Float:timerStartDelay;
new Float:hordeCountdown;
new Float:minProgress;
new Float:aliveSince[MAXPLAYERS + 1];
new Float:startingSurvivorCompletion;

new hordeDelayChecks;

new L4D2SI:zombieclass[MAXPLAYERS + 1];

public Plugin:myinfo = 
{
	name = "L4D2 Antibaiter",
	author = "Visor, Sir (assisted by Devilesk)",
	description = "Makes you think twice before attempting to bait that shit",
	version = "1.3",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public OnPluginStart()
{
	hCvarTimerStartDelay = CreateConVar("l4d2_antibaiter_delay", "20", "Delay in seconds before the antibait algorithm kicks in", FCVAR_NONE);
	hCvarHordeCountdown = CreateConVar("l4d2_antibaiter_horde_timer", "60", "Countdown in seconds to the panic horde", FCVAR_NONE);
	hCvarMinProgressThreshold = CreateConVar("l4d2_antibaiter_progress", "0.03", "Minimum progress the survivors must make to reset the antibaiter timer", FCVAR_NONE);
	CreateTimer(1.0, AntibaiterThink, _, TIMER_REPEAT);
}
public OnConfigsExecuted()
{
	timerStartDelay = GetConVarFloat(hCvarTimerStartDelay);
	hordeCountdown = GetConVarFloat(hCvarHordeCountdown);
	minProgress = GetConVarFloat(hCvarMinProgressThreshold);
}
public Action:L4D_OnFirstSurvivorLeftSafeArea() 
{
	hordeDelayChecks = 0;
	ServerCommand("sm_cvar infected_tele_enable 1");
	if (IsCountdownRunning())
	{
		StopCountdown();
	}

}	
public Action:AntibaiterThink(Handle:timer) 
{


	// 5th SI / spectator bug workaround

		new Float:survivorCompletion = GetMaxSurvivorCompletion();
		new Float:progress = Float:survivorCompletion - Float:startingSurvivorCompletion;
		if (progress <= minProgress
			&& hordeDelayChecks >= RoundToNearest(timerStartDelay))
		{
		#if DEBUG
			PrintToChatAll("\x03[Antibaiter DEBUG] Minimum progress unsatisfied during \x05%d\x01 checks: \x04initial\x01=\x05%f\x01, \x04current\x01=\x05%f\x01, \x04progress\x01=\x05%f\x01", hordeDelayChecks, startingSurvivorCompletion, survivorCompletion, progress);
		#endif
			if (IsCountdownRunning())
			{
			#if DEBUG
				PrintToChatAll("\x03[Antibaiter DEBUG] Countdown is \x05running\x01");
			#endif
				if (HasCountdownElapsed())
				{
				#if DEBUG
					PrintToChatAll("\x03[Antibaiter DEBUG] Countdown has \x04elapsed\x01! Launching horde and resetting checks counter");
				#endif
					LaunchHorde();
					hordeDelayChecks = 0;
				}
			}
			else
			{
			#if DEBUG
				PrintToChatAll("\x03[Antibaiter DEBUG] Countdown is \x05not running\x01. Initiating it...");
			#endif
				InitiateCountdown();
			}
		}
		else
		{
			if (hordeDelayChecks == 0)
			{
				startingSurvivorCompletion = survivorCompletion;
			}
			if (progress > minProgress)
			{
			#if DEBUG
				PrintToChatAll("\x03[Antibaiter DEBUG] Survivor progress has \x05increased\x01 beyond the minimum threshold. Resetting the algorithm...");
			#endif
				startingSurvivorCompletion = survivorCompletion;
				hordeDelayChecks = 0;
				ServerCommand("sm_cvar infected_tele_enable 1");
			}

			hordeDelayChecks++;
			StopCountdown();
		}
	
	return Plugin_Handled;
}

public L4D_OnEnterGhostState(client)
{
	zombieclass[client] = GetZombieClass(client);
	aliveSince[client] = GetGameTime();
}

/*******************************/
/** Horde/countdown functions **/
/*******************************/

InitiateCountdown()
{
	CTimer_Start(CountdownPointer(), hordeCountdown);
}

bool:IsCountdownRunning()
{
	return CTimer_HasStarted(CountdownPointer());
}

bool:HasCountdownElapsed()
{
	return CTimer_IsElapsed(CountdownPointer());
}

StopCountdown()
{
	CTimer_Invalidate(CountdownPointer());

}

LaunchHorde()
{
	ServerCommand("sm_cvar infected_tele_enable 0");
}

CountdownTimer:CountdownPointer()
{
	return L4D2Direct_GetScavengeRoundSetupTimer();
}

/************/
/** Stocks **/
/************/

Float:GetMaxSurvivorCompletion()
{
	new Float:flow = 0.0;
	for (new i = 1; i <= MaxClients; i++)
	{
		// Prevent rushers from convoluting the logic
		if (IsSurvivor(i) && IsPlayerAlive(i) && !IsIncapped(i))
		{
			flow = MAX(flow, L4D2Direct_GetFlowDistance(i));
		}
	}
	return (flow / L4D2Direct_GetMapMaxFlowDistance());
}

bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

L4D2SI:GetZombieClass(client)
{
	return L4D2SI:GetEntProp(client, Prop_Send, "m_zombieClass");
}

bool:IsIncapped(client)
{
	return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
}


stock Address:L4D2_GetCDirectorScriptedEventManager()
{
	static Address:pScriptedEventManager = Address_Null;
	if (pScriptedEventManager == Address_Null)
	{
		new offs = GameConfGetOffset(GetGameConf(), "ScriptedEventManagerPtr");
		if(offs == -1) return Address_Null;
		pScriptedEventManager = GetCDirector() + Address:offs;
		pScriptedEventManager = Address:LoadFromAddress(pScriptedEventManager , NumberType_Int32);
	}
	return pScriptedEventManager;
}

stock Handle:GetGameConf()
{
	static Handle:g_hGameConf_l4dhooks = INVALID_HANDLE;
	if(g_hGameConf_l4dhooks == INVALID_HANDLE)
	{
		g_hGameConf_l4dhooks = LoadGameConfigFile("left4dhooks.l4d2");
	}
	return g_hGameConf_l4dhooks;
}

stock Address:GetCDirector()
{
	static Address:TheDirector = Address_Null;
	if(TheDirector == Address_Null)
	{
		TheDirector = GameConfGetAddress(GetGameConf(), "CDirector");
	}
	return TheDirector;
}
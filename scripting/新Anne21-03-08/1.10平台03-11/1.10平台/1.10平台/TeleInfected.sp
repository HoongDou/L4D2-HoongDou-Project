#pragma semicolon 1
#pragma tabsize 0
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <lgofnoc>
#define UNINITIALISED_FLOAT -1.42424
#define NAV_MESH_HEIGHT 20.0
#define COORD_X 0
#define COORD_Y 1
#define COORD_Z 2
#define X_MIN 0
#define X_MAX 1
#define Y_MIN 2
#define Y_MAX 3
#define PITCH 0
#define YAW 1
#define ROLL 2
#define MAX_ANGLE 89.0
float spawnGrid[4];
#define TRACE_TOLERANCE 150.0

static const char CLASSNAME_INFECTED[] = "infected";
static const char CLASSNAME_WITCH[] = "witch";
static const char CLASSNAME_PHYSPROPS[] = "prop_physics";
enum AimTarget
{
        AimTarget_Eye,
        AimTarget_Body,
        AimTarget_Chest
};
public Plugin myinfo = 
{
	name = "特感传送",
	author = "AnneHappy",
	description = "特感传送",
	version = "1.10",
	url = "https://share.weiyun.com/DCVy3LUs"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	MarkNativeAsOptional("L4D2_GetSurvivorOfIndex");
	RegPluginLibrary("lgofnoc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("player_spawn", OnPlayerSpawnPre, EventHookMode_PostNoCopy);
}

public Action OnPlayerSpawnPre(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(!IsBotInfected(client)) return;
	int iClass = GetInfectedClass(client);
	if ((iClass > 0 && iClass <= 6))
	CreateTimer(0.1, Timer_PositionSI, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_PositionSI(Handle timer, any infectedBot)
{
	if (!IsBotInfected(infectedBot) || !IsPlayerAlive(infectedBot)) return Plugin_Stop;
	static float fOwnerOrigin[3];
	GetEntPropVector(infectedBot, Prop_Send, "m_vecOrigin", fOwnerOrigin);
	if(GetSurvivorProximity(fOwnerOrigin) > 500.0 && CanBeTP(infectedBot) && TooFar(infectedBot))
	RepositionGrid(infectedBot);
	return Plugin_Continue;
}


bool TooFar(int client)
{
	float fInfLocation[3]; float fSurvLocation[3]; float fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	//new Discard_range = GetConVarInt(g_hDiscardRange);
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int index = i;
			if (!IsPlayerAlive(index)) continue;
			GetClientAbsOrigin(index, fSurvLocation);
		
			MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
		
			if (GetVectorLength(fVector) <= 500)			
			return false;
		}
	}
	return true;
}
bool CanBeTP(int client)
{
	float Origin[3];
	//Origin[COORD_Z] += 50.0;
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", Origin);
	if (!IsClientInGame(client) || !IsFakeClient(client))return false;
	if (GetClientTeam(client) != 3 || !IsPlayerAlive(client))return false;
	if(IsVisibleToSurvivors(client) || PlayerVisibleTo(Origin))return false;
	if(GetEntProp(client, Prop_Send, "m_hasVisibleThreats"))return false;
	return true;
}

int GetSurvivorProximity(float referencePos[3], int specificSurvivor = -1)
{
	int targetSurvivor;
	float targetSurvivorPos[3];
	if(specificSurvivor > 0 && IsValidSurvivor(specificSurvivor)) targetSurvivor = specificSurvivor;
	else targetSurvivor = GetClosestSurvivor(referencePos);
	GetEntPropVector( targetSurvivor, Prop_Send, "m_vecOrigin", targetSurvivorPos );
	return RoundToNearest( GetVectorDistance(referencePos, targetSurvivorPos) );
}
int GetClosestSurvivor(float referencePos[3], int excludeSurvivor = -1)
{
	float survivorPos[3];
	int iClosestAbsDisplacement = -1; 
	int closestSurvivor = -1;		
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0 && index != excludeSurvivor)
		{
			GetClientAbsOrigin(index, survivorPos);
			int iAbsDisplacement = RoundToNearest(GetVectorDistance(referencePos, survivorPos));			
			if(iClosestAbsDisplacement < 0)
			{
				iClosestAbsDisplacement = iAbsDisplacement;
				closestSurvivor = index;
			} else if(iAbsDisplacement < iClosestAbsDisplacement)
			{
				iClosestAbsDisplacement = iAbsDisplacement;
				closestSurvivor = index;
			}			
		}
	}
	return closestSurvivor;
}
bool RepositionGrid(int infectedBot)
{
		UpdateSpawnGrid();
		float gridPos[3];
		int closestSurvivor = GetClosestSurvivor2D(gridPos);
		float survivorPos[3];
		gridPos[COORD_X] = GetRandomFloat(spawnGrid[X_MIN], spawnGrid[X_MAX]);
		gridPos[COORD_Y] = GetRandomFloat(spawnGrid[Y_MIN], spawnGrid[Y_MAX]);
		GetClientAbsOrigin(closestSurvivor, survivorPos);
		gridPos[COORD_Z] = survivorPos[COORD_Z] + 0.0;
			
		if(IsValidSurvivor(closestSurvivor) && IsPlayerAlive(closestSurvivor))
		{
			float direction[3];
			direction[PITCH] = MAX_ANGLE;
			direction[YAW] = 0.0;
			direction[ROLL] = 0.0;
			TR_TraceRay(gridPos, direction, MASK_ALL, RayType_Infinite);
			if(TR_DidHit())
			{
				float traceImpact[3], spawnPos[3];
				TR_GetEndPosition(traceImpact); 
				spawnPos = traceImpact;
				spawnPos[COORD_Z] += NAV_MESH_HEIGHT;
				if(IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, infectedBot))
				{
					if( !HasSurvivorLOS(spawnPos) && (200.0 < GetSurvivorProximity(spawnPos) < 500.0) && !PlayerVisibleTo(spawnPos))
					{
						//PrintToChatAll("找位成功");
						TeleportEntity( infectedBot, spawnPos, NULL_VECTOR, NULL_VECTOR);
						return true;
					}
				}
			} 
		}
		return false;
}
	
void UpdateSpawnGrid()
{
	spawnGrid[X_MIN] = UNINITIALISED_FLOAT, spawnGrid[Y_MIN] = UNINITIALISED_FLOAT;
	spawnGrid[X_MAX] = UNINITIALISED_FLOAT, spawnGrid[Y_MAX] = UNINITIALISED_FLOAT;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			float pos[3];
			GetClientAbsOrigin(index, pos);
			spawnGrid[X_MIN] = CheckMinCoord( spawnGrid[X_MIN], pos[COORD_X] );
			spawnGrid[Y_MIN] = CheckMinCoord( spawnGrid[Y_MIN], pos[COORD_Y] );
			spawnGrid[X_MAX] = CheckMaxCoord( spawnGrid[X_MAX], pos[COORD_X] );
			spawnGrid[Y_MAX] = CheckMaxCoord( spawnGrid[Y_MAX], pos[COORD_Y] );
		}
	}
	float borderWidth = 500.0;
	spawnGrid[X_MIN] -= borderWidth;
	spawnGrid[Y_MIN] -= borderWidth;
	spawnGrid[X_MAX] += borderWidth;
	spawnGrid[Y_MAX] += borderWidth;
}

int GetClosestSurvivor2D(float gridPos[3])
{
	float proximity = UNINITIALISED_FLOAT;
	int closestSurvivor = -1;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			float survivorPos[3];
			GetClientAbsOrigin(index, survivorPos);
			float survivorDistance = SquareRoot( Pow(survivorPos[COORD_X] - gridPos[COORD_X], 2.0) + Pow(survivorPos[COORD_Y] - gridPos[COORD_Y], 2.0) );
			if(survivorDistance < proximity || proximity == UNINITIALISED_FLOAT)
			{
				proximity = survivorDistance;
				closestSurvivor = index;
			}
		}
	}
	return closestSurvivor;
}

float CheckMinCoord(float oldMin, float checkValue)
{
	if(checkValue < oldMin || oldMin == UNINITIALISED_FLOAT) return checkValue;
	else return oldMin;
}

float CheckMaxCoord(float oldMax, float checkValue)
{
	if(checkValue > oldMax || oldMax == UNINITIALISED_FLOAT) return checkValue;
	else return oldMax;
}

int GetSurvivor()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == 2)
            return i;
    }
}

bool IsBotInfected(int client)
{
    if (IsValidInfected(client) && IsFakeClient(client)) return true;
    return false;
}

bool IsOnValidMesh(float pos[3])
{
	Address pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(pos);
	if (pNavArea != Address_Null) return true;
	else return false;
}

bool IsPlayerStuck(float pos[3], int client)
{
	bool isStuck = true;
	if(IsValidInGame(client))
	{
		float mins[3], maxs[3];		
		GetClientMins(client, mins);
		GetClientMaxs(client, maxs);
		for(int i = 0; i < sizeof(mins); i++)
		{
		    mins[i] -= 3;
		    maxs[i] += 3;
		}
		TR_TraceHullFilter(pos, pos, mins, maxs, MASK_ALL, TraceFilter, client);
		isStuck = TR_DidHit();
	}
	return isStuck;
}

bool IsVisibleToSurvivors(int entity)
{
	int iSurv;

	for (int  i = 1; i <= MaxClients && iSurv < 5; i++)
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

bool IsVisibleTo(int client, int entity)
{
	float vAngles[3];float vOrigin[3];float vEnt[3] ;float vLookAt[3];
	GetClientEyePosition(client,vOrigin);
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vEnt);
	MakeVectorFromPoints(vOrigin, vEnt, vLookAt);
	GetVectorAngles(vLookAt, vAngles);
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilter);
	bool isVisible = false;
	if (TR_DidHit(trace))
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace);
		
		if ((GetVectorDistance(vOrigin, vStart, false) + TRACE_TOLERANCE) >= GetVectorDistance(vOrigin, vEnt))
		{
			isVisible = true;
		}
	}
	else
	{
		isVisible = true; 
	}
	
	CloseHandle(trace);
	return isVisible;
}

bool TraceFilter(int entity, int contentsMask)
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	char class[128];
	GetEdictClassname(entity, class, sizeof(class));
	if (StrEqual(class, CLASSNAME_INFECTED, .caseSensitive = false)
	|| StrEqual(class, CLASSNAME_WITCH, .caseSensitive = false)
	|| StrEqual(class, CLASSNAME_PHYSPROPS, .caseSensitive = false))
	{
		return false;
	}
	return true;
}

stock bool PlayerVisibleTo(const float spawnpos[3])
{
	static float pos[3];
	pos[0] = spawnpos[0];
	pos[1] = spawnpos[1];
	pos[2] = spawnpos[2] + 45.0;
	static int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if(PosIsVisibleTo(i, pos))
			{
				//pos[2] = spawnpos[2] - 90.0;
				return true;
			}
			else if(PosIsVisibleTo(i, pos))
			{
				return true;
			}
		}
	}
	return false;
}
stock bool PlayerVisibleToEx(const float spawnpos[3])
{
	static int i;
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			if(PosIsVisibleTo(i, spawnpos))
				return true;
		}
	}
	return false;
}

stock bool PosIsVisibleTo(int client, const float targetposition[3])
{
	static float position[3], vAngles[3], vLookAt[3];
	GetClientEyePosition(client, position);
	MakeVectorFromPoints(position, targetposition, vLookAt); // compute vector from start to target
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace

	// execute Trace
	static Handle trace;
	trace = TR_TraceRayFilterEx(position, vAngles, MASK_VISIBLE, RayType_Infinite, TracerayFilter, client);

	static bool isVisible;
	isVisible = false;
	if(TR_DidHit(trace))
	{
		static float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint

		if((GetVectorDistance(position, vStart, false) + 25.0) >= GetVectorDistance(position, targetposition))
			isVisible = true; // if trace ray length plus tolerance equal or bigger absolute distance, you hit the target
	}
	delete trace;
	return isVisible;
}

public bool TracerayFilter(int entity, int contentMask) 
{
	if (entity <= MaxClients || !IsValidEntity(entity))
	{
		return false;
	}
	char class[128];
	GetEdictClassname(entity, class, sizeof(class));
	if (StrEqual(class, CLASSNAME_INFECTED, .caseSensitive = false)
	|| StrEqual(class, CLASSNAME_WITCH, .caseSensitive = false)
	|| StrEqual(class, CLASSNAME_PHYSPROPS, .caseSensitive = false))
	{
		return false;
	}
	return true;
}
bool HasSurvivorLOS(float pos[3])
{
	bool hasLOS = false;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			float origin[3];
			GetClientAbsOrigin(index, origin);
			TR_TraceRay(pos, origin, MASK_ALL, RayType_EndPoint);
			if(!TR_DidHit())
			{
				hasLOS = true;
				break;
			}
		}	
	}
	return hasLOS;
}
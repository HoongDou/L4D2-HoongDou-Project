#pragma semicolon 1

#define PI 3.14159265359
#define UNINITIALISED_FLOAT -1.42424

#define BOUNDINGBOX_INFLATION_OFFSET 3
#define NAV_MESH_HEIGHT 20.0
#define DEBUG_DRAW_ELEVATION 100.0
#define TRACE_TOLERANCE 75.0
static const String:CLASSNAME_INFECTED[]			= "infected";
static const String:CLASSNAME_WITCH[]				= "witch";
static const String:CLASSNAME_PHYSPROPS[]			= "prop_physics";
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

#define INVALID_MESH 0
#define VALID_MESH 1
#define SPAWN_FAIL 2
#define WHITE 3
#define PURPLE 4

#include <l4d2_direct>

new Handle:hCvarSpawnPositionerMode;
new Handle:hCvarMaxSearchAttempts;
new Handle:hCvarSpawnSearchHeight;
new Handle:hCvarSpawnProximityMin;
new Handle:hCvarSpawnProximityMax;
new Handle:hCvarSpawnProximityFlowNoLOS;
new Handle:hCvarSpawnProximityFlowLOS; 

new g_AllSurvivors[MAXPLAYERS]; // MAXPLAYERS because who knows what survivor limit people may use
new Float:spawnGrid[4];

new laserCache;

/*
 * Bibliography
 * - Epilimic's witch spawner code
 * - "Player-Teleport by Dr. HyperKiLLeR" (sm_gotoRevA.smx)
 * Thanks to Newteee for his repositioning algorithm
 */

SpawnPositioner_OnModuleStart() {
	hCvarSpawnPositionerMode = CreateConVar( "ss_spawnpositioner_mode", "2", "[ 0 = disabled, 1 = Radial Reposition only, 2 = Grid Reposition with Radial fallback ]" );
	HookConVarChange( hCvarSpawnPositionerMode, ConVarChanged:SpawnPositionerMode );
	hCvarMaxSearchAttempts = CreateConVar( "ss_spawn_max_search_attempts", "500", "Max attempts to make per SI spawn to find an acceptable location to which to relocate them" );
	hCvarSpawnSearchHeight = CreateConVar( "ss_spawn_search_height", "50", "Attempts to find a valid spawn location will move down from this height relative to a survivor");
	hCvarSpawnProximityMin = CreateConVar( "ss_spawn_proximity_min", "500", "Closest an SI may spawn to a survivor", FCVAR_PLUGIN, true, 1.0 );
	hCvarSpawnProximityMax = CreateConVar( "ss_spawn_proximity_max", "650", "Furthest an SI may spawn to a survivor", FCVAR_PLUGIN, true, float(GetConVarInt(hCvarSpawnProximityMin)) );
	// N.B. the hCvarSpawnProximityFlow___ cvars are not a lower and upper bound;
	hCvarSpawnProximityFlowNoLOS = CreateConVar( "ss_spawn_proximity_flow_dist_no_LOS", "500", 
									"Closest spawns by flow distance; considered when there is no LOS on survivors" );
	hCvarSpawnProximityFlowLOS = CreateConVar( "ss_spawn_proximity_flow_dist_LOS", "900", 
									"Farthest spawns by flow distance; bounded by lowest straight line distance to survivor team" );
	HookEvent("player_spawn", OnPlayerSpawnPost, EventHookMode_PostNoCopy);
}

SpawnPositioner_OnModuleEnd() {
	ResetConVar( FindConVar("z_spawn_range") );
}

public SpawnPositionerMode() {
	if( GetConVarBool(hCvarSpawnPositionerMode) ) {
		ResetConVar( FindConVar("z_spawn_range") ); // default value is 1500
	} else {
		SetConVarInt( FindConVar("z_spawn_range"), 1000 ); // spawn SI closer as they are not being repositioned; no second chances for failed spawns
	}
}

/***********************************************************************************************************************************************************************************

                                     						REPOSITION SI PROMPTLY AFTER SPAWNING
                                                                    
***********************************************************************************************************************************************************************************/

public OnPlayerSpawnPost(Handle:event, const String:name[], bool:dontBroadcast) {

    new userid = GetEventInt(event, "userid");
    new client = GetClientOfUserId(userid);
    if( IsBotInfected(client) ) 
	{
    	CreateTimer( 0.2, Timer_PositionSI, userid, TIMER_FLAG_NO_MAPCHANGE );
    }
}

public Action:Timer_PositionSI(Handle:timer, any:userid) 
{
	RepositionRadial( userid, GetRandomSurvivor() );
	return Plugin_Stop;
}

/***********************************************************************************************************************************************************************************

                                             					GRID REPOSITIONING SYSTEM
                                                                    
***********************************************************************************************************************************************************************************/

/*
 * Reposition the SI to a random point on a 2D grid around the survivors. 
 */
RepositionGrid( userid ) {
	new infectedBot = GetClientOfUserId(userid);
	
	if ( !IsBotInfected(infectedBot) || !IsPlayerAlive(infectedBot) ) {
		return;
	}
	
	UpdateSpawnGrid();
	
	for( new i = 0; i < GetConVarInt(hCvarMaxSearchAttempts); i++ ) 
	{
		new Float:gridPos[3];
		new Float:survivorPos[3];
		new closestSurvivor;
		
		// 'x' and 'y' for potential spawn point coordinates is selected with uniform RNG
		gridPos[COORD_X] = GetRandomFloat(spawnGrid[X_MIN], spawnGrid[X_MAX]);
		gridPos[COORD_Y] = GetRandomFloat(spawnGrid[Y_MIN], spawnGrid[Y_MAX]);
		// 'z' for potential spawn point coordinate is taken from just above the height of nearest survivor
		closestSurvivor = GetClosestSurvivor2D(gridPos);
		GetClientAbsOrigin(closestSurvivor, survivorPos);
		gridPos[COORD_Z] = survivorPos[COORD_Z] + float( GetConVarInt(hCvarSpawnSearchHeight) );
		
		// Search down the vertical column from the generated [x, y ,z] coordinate for a valid spawn position
		new Float:direction[3];
		direction[PITCH] = MAX_ANGLE; // straight down
		direction[YAW] = 0.0;
		direction[ROLL] = 0.0;
		TR_TraceRay( gridPos, direction, MASK_ALL, RayType_Infinite );
		
		// found solid land below the [x, y, z] coordinate
		if( TR_DidHit() ) { 
			new Float:traceImpact[3];
			new Float:spawnPos[3];
			
			TR_GetEndPosition( traceImpact ); 
			spawnPos = traceImpact;
			spawnPos[COORD_Z] += NAV_MESH_HEIGHT; // from testing I presume the SI cannot spawn on the floor itself
			
			if ( IsValidSpawn(infectedBot, spawnPos)) 
			{
			
					#if DEBUG_POSITIONER
						DrawSpawnGrid();
						new String:client_name[32];
						GetClientName(GetClientOfUserId(userid), client_name, sizeof(client_name));
						Client_PrintToChatAll(true, "[SS] {O}%s{N} GRID SPAWN, {R}%d{N} dist, ( {G}%d{N} attempts)", client_name, RoundFloat(GetFlowDistToSurvivors(spawnPos)), i + 1);
						gridPos[COORD_Z] = DEBUG_DRAW_ELEVATION;
						DrawBeam( gridPos, spawnPos, VALID_MESH );
					#endif
					
				TeleportEntity( infectedBot, spawnPos, NULL_VECTOR, NULL_VECTOR ); // all spawn conditions satisifed
				return;
				
			} else {

					#if DEBUG_POSITIONER
						DrawSpawnGrid();
						gridPos[COORD_Z] = DEBUG_DRAW_ELEVATION;
						DrawBeam( gridPos, spawnPos, INVALID_MESH );
					#endif
					
			}
		} 
 	}
 	// Could not find an acceptable spawn position
	LogMessage("[SS] FAILED to find a valid GRID SPAWN position for userid '%d' after %d attempts", userid, GetConVarInt(hCvarMaxSearchAttempts) ); 
	return;
 }
 
bool:IsValidSpawn(infectedBot, const Float:spawnPos[3]) 
{
	new bool:is_valid = false;
	new flow_dist_survivors;
	if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, infectedBot) ) 
	{
		flow_dist_survivors = GetFlowDistToSurvivors(spawnPos);
		if ( HasSurvivorLOS(spawnPos) ) 
		{
			new survivor_proximity = GetSurvivorProximity(spawnPos);
			if ( survivor_proximity > GetConVarInt(hCvarSpawnProximityMin) && flow_dist_survivors < GetConVarInt(hCvarSpawnProximityFlowLOS)) 
			{ 
				is_valid = true;
			}
		} else { // try to keep spawn flow distance to survivors low if they are spawning outside of LOS
			if ( flow_dist_survivors < GetConVarInt(hCvarSpawnProximityFlowNoLOS) && flow_dist_survivors != -1) {
					
					#if DEBUG_POSITIONER
						Client_PrintToChatAll(true, "{G}flow dist %d{N} < cvar {G}%d{N}", flow_dist_survivors, GetConVarInt(hCvarSpawnProximityFlowNoLOS));
					#endif
				
				is_valid = true;
			}
		}
	}
	return is_valid;
}

GetClosestSurvivor2D(Float:gridPos[3]) {
	// Use the 'z' coordinate of the nearest survivor
	new Float:proximity = UNINITIALISED_FLOAT;
	new closestSurvivor = GetRandomSurvivor();
	for( new j = 1; j < MaxClients; j++ ) {
		if( IsSurvivor(j) && IsPlayerAlive(j) ) {
			new Float:survivorPos[3];
			GetClientAbsOrigin( j, survivorPos );
			// Pythagoras
			new Float:survivorDistance = SquareRoot( Pow(survivorPos[COORD_X] - gridPos[COORD_X], 2.0) + Pow(survivorPos[COORD_Y] - gridPos[COORD_Y], 2.0) );
			if( survivorDistance < proximity || proximity == UNINITIALISED_FLOAT ) {
				proximity = survivorDistance;
				closestSurvivor = j;
			}
		}
	}
	return closestSurvivor;
}

UpdateSpawnGrid() {
	// Grid will have coords (min X, min Y), (min X, max Y), (max X, min Y), (max X, max Y)
	spawnGrid[X_MIN] = UNINITIALISED_FLOAT, spawnGrid[Y_MIN] = UNINITIALISED_FLOAT;
	spawnGrid[X_MAX] = UNINITIALISED_FLOAT, spawnGrid[Y_MAX] = UNINITIALISED_FLOAT;
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsSurvivor(i) && IsPlayerAlive(i)) {
			new Float:pos[3];
			GetClientAbsOrigin(i, pos);
			// Check min
			spawnGrid[X_MIN] = CheckMinCoord( spawnGrid[X_MIN], pos[COORD_X] );
			spawnGrid[Y_MIN] = CheckMinCoord( spawnGrid[Y_MIN], pos[COORD_Y] );
			// Check max
			spawnGrid[X_MAX] = CheckMaxCoord( spawnGrid[X_MAX], pos[COORD_X] );
			spawnGrid[Y_MAX] = CheckMaxCoord( spawnGrid[Y_MAX], pos[COORD_Y] );
		}
	}
	// Extend a border around grid
	new Float:borderWidth = float( GetConVarInt(hCvarSpawnProximityMax) );
	spawnGrid[X_MIN] -= borderWidth;
	spawnGrid[Y_MIN] -= borderWidth;
	spawnGrid[X_MAX] += borderWidth;
	spawnGrid[Y_MAX] += borderWidth;
}

Float:CheckMinCoord( Float:oldMin, Float:checkValue ) {
	if( checkValue < oldMin || oldMin == UNINITIALISED_FLOAT ) {
		return checkValue;
	} else {
		return oldMin;
	}
}

Float:CheckMaxCoord( Float:oldMax, Float:checkValue ) {
	if( checkValue > oldMax || oldMax == UNINITIALISED_FLOAT ) {
		return checkValue;
	} else {
		return oldMax;
	}
}

stock DrawSpawnGrid() {
	new Float:xMin = spawnGrid[X_MIN];
	new Float:xMax = spawnGrid[X_MAX];
	new Float:yMin = spawnGrid[Y_MIN];
	new Float:yMax = spawnGrid[Y_MAX];
	new Float:z = DEBUG_DRAW_ELEVATION;
	new Float:bottomLeft[3]; 
	bottomLeft[0] = xMin;
	bottomLeft[1] = yMin;
	bottomLeft[2] = z;
	new Float:topLeft[3];
	topLeft[0] = xMin;
	topLeft[1] = yMax;
	topLeft[2] = z;
	new Float:topRight[3];
	topRight[0] = xMax;
	topRight[1] = yMax;
	new Float:bottomRight[3]; 
	bottomRight[0] = xMax;
	bottomRight[1] = yMin;
	bottomLeft[2] = z;
	topRight[2] = z;
	DrawBeam( bottomLeft, topLeft, PURPLE );  
	DrawBeam( topLeft, topRight, PURPLE ); 
	DrawBeam( topRight, bottomRight, PURPLE );  
	DrawBeam( bottomRight, bottomLeft, PURPLE );  
}

/***********************************************************************************************************************************************************************************

                                             					RADIAL REPOSITION SYSTEM
                                                                    
***********************************************************************************************************************************************************************************/

/*
 * Reposition the SI to a point on the circumference of a circle [spawn_proximity] from a survivor; respects distance to all survivors
 * Always spawns SI at [ss_spawn_proximity_min] distance to survivors
 */
RepositionRadial( userid, survivorTarget ) 
{
	new bool:repositionSuccess = false;
	new client = GetClientOfUserId(userid); // userid preferable for preventing bugs as 'client' refers to one of thirty two client slots
	if( IsBotInfected(client) && IsPlayerAlive(client) ) 
	{
		new Float:survivorPos[3];
		new Float:rayEnd[3];
		new Float:spawnPos[3] = {-1.0, -1.0, -1.0};
		for( new i = 0; i < GetConVarInt(hCvarMaxSearchAttempts); i++ ) 
		{
			// Fire a ray at a random angle around the survivor
			GetClientAbsOrigin(survivorTarget, survivorPos); 
			new Float:spawnSearchAngle = GetRandomFloat(0.0, 2.0 * PI);
			rayEnd[0] = survivorPos[0] + Sine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximityMin);
			rayEnd[1] = survivorPos[1] + Cosine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximityMin);
			rayEnd[2] = survivorPos[2] + GetConVarInt(hCvarSpawnSearchHeight);
			// Search down the vertical column from the ray's' endpoint for a valid spawn position
			new Float:direction[3];
			direction[PITCH] = MAX_ANGLE; // straight down
			direction[YAW] = 0.0;
			direction[ROLL] = 0.0;
			TR_TraceRay( rayEnd, direction, MASK_ALL, RayType_Infinite );
			if( TR_DidHit()) 
			{
				new Float:traceImpact[3];
				TR_GetEndPosition( traceImpact );
				spawnPos = traceImpact;
				spawnPos[COORD_Z] += NAV_MESH_HEIGHT; // from testing I presume the SI cannot spawn on the floor itself
				if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, client) && GetSurvivorProximity(spawnPos) > GetConVarInt(hCvarSpawnProximityMin)  && !IsVisibleToSurvivors(spawnPos)) 
				{
						
						#if DEBUG_POSITIONER
							LogMessage("[SS] ( %d attempts ) Found a valid RADIAL SPAWN position for userid '%d'", i, userid );
							DrawBeam( survivorPos, rayEnd, VALID_MESH );
							DrawBeam( rayEnd, spawnPos, VALID_MESH ); 
						#endif
						
					TeleportEntity( client, spawnPos, NULL_VECTOR, NULL_VECTOR ); 
					repositionSuccess = true;
					break;
					
				} 
				else 
				{
				
						#if DEBUG_POSITIONER
							DrawBeam( survivorPos, rayEnd, INVALID_MESH );
							DrawBeam( rayEnd, spawnPos, WHITE ); 
						#endif
						
				}
			}
		}
		
		// Could not find an acceptable spawn position
		if(!repositionSuccess) {
			LogMessage("[SS] FAILED to find a valid RADIAL SPAWN position for userid '%d' after %d attempts", client, GetConVarInt(hCvarMaxSearchAttempts) ); 
		}		
	}
}

/***********************************************************************************************************************************************************************************

                                                                      UTILITY	
                                                                    
***********************************************************************************************************************************************************************************/
stock bool:HasSurvivorLOS( const Float:pos[3] ) {
	new bool:hasLOS = false;
	for( new i = 1; i < MaxClients; ++i ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
			new Float:origin[3];
			GetClientAbsOrigin(i, origin);
			TR_TraceRay( pos, origin, MASK_ALL, RayType_EndPoint );
			if( !TR_DidHit() ) {
				hasLOS = true;
				break;
			}
		}	
	}
	return hasLOS;
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
	
	else
	{
		//Debug=Uprint（“僵尸设计故障：玩家-僵尸痕迹没有击中任何东西，WTF”）；
		isVisible = true;
	}
	
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
GetLeadSurvivor() {
	// Find the farthest flow held by a survivor
	new Float:farthestFlow = -1.0;
	new leadSurvivor = -1;
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
			new Float:origin[3];
			GetClientAbsOrigin(i, origin);
			new Address:pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if( pNavArea != Address_Null ) {
				new Float:tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				if( tmp_flow > farthestFlow || farthestFlow == -1.0 ) {
					farthestFlow = tmp_flow;
					leadSurvivor = i;
				}
			}
		}
	}
	return leadSurvivor;
}

GetRearSurvivor() {
	// Find the farthest flow held by a survivor
	new Float:lowestFlow = -1.0;
	new rearSurvivor = -1;
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsSurvivor(i) && IsPlayerAlive(i) ) {
			new Float:origin[3];
			GetClientAbsOrigin(i, origin);
			new Address:pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if( pNavArea != Address_Null ) {
				new Float:tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				if( tmp_flow < lowestFlow || lowestFlow == -1.0 ) {
					lowestFlow = tmp_flow;
					rearSurvivor = i;
				}
			}
		}
	}
	return rearSurvivor;
}

bool:IsPlayerStuck( const Float:pos[3], client) 
{
	new bool:isStuck = true;
	if( IsValidClient(client)) 
	{
		new Float:mins[3];
		new Float:maxs[3];		
		GetClientMins(client, mins);
		GetClientMaxs(client, maxs);
		
		// inflate the sizes just a little bit
		for( new i = 0; i < sizeof(mins); i++ ) 
		{
		    mins[i] -= BOUNDINGBOX_INFLATION_OFFSET;
		    maxs[i] += BOUNDINGBOX_INFLATION_OFFSET;
		}
		
		TR_TraceHullFilter(pos, pos, mins, maxs, MASK_ALL, TraceEntityFilterPlayer, client);
		isStuck = TR_DidHit();
	}
	return isStuck;
}  

// filter out players, since we can't get stuck on them
public bool:TraceEntityFilterPlayer(entity, contentsMask) {
    return entity <= 0 || entity > MaxClients;
}  

/** @return: the last array index of g_AllSurvivors holding a valid survivor */
stock CacheSurvivors() {
	new j = 0;
	for( new i = 0; i < MAXPLAYERS; i++ ) {
		if( IsSurvivor(i) ) {
		    g_AllSurvivors[j] = i;
		    j++;
		}
	}
	return (j - 1);
}

stock bool:IsOnValidMesh(const Float:position[3]) {
	new Float:pos[3];
	pos[0] = position[0]; 
	pos[1] = position[1]; 
	pos[2] = position[2]; 
	new Address:pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(pos);
	if (pNavArea != Address_Null) 
	{ 
		return true;
	} 
	else 
	{
		return false;
	}
}

stock DrawBeam( Float:startPos[3], Float:endPos[3], spawnResult ) {
	laserCache = PrecacheModel("materials/sprites/laserbeam.vmt");
	new Color[5][4]; 
	Color[VALID_MESH] = {0, 255, 0, 75}; // green
	Color[INVALID_MESH] = {255, 0, 0, 75}; // red
	Color[SPAWN_FAIL] = {255, 140, 0, 75}; // orange
	Color[WHITE] = {255, 255, 255, 75}; // white
	Color[PURPLE] = {128, 0, 128, 75}; // purple
	new Float:beamDuration = 5.0;
	TE_SetupBeamPoints(startPos, endPos, laserCache, 0, 1, 1, beamDuration, 5.0, 5.0, 4, 0.0, Color[spawnResult], 0);
	new iSurvivors[MaxClients];
	new iNumSurvivors = 0;
	for( new i = 1; i < MaxClients; i++ ) {
		if( IsSurvivor(i) && !IsFakeClient(i) ) {
			iSurvivors[iNumSurvivors] = i;
			iNumSurvivors++;
		}
	}
	TE_Send( iSurvivors, iNumSurvivors ); 
}
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>

#define VERSION "2.0.8"

ConVar g_hEnabled;
ConVar g_hWeaponRandom;
ConVar g_hWeaponRandomAmount;
ConVar g_hWeaponBaseballBat;
ConVar g_hWeaponCricketBat;
ConVar g_hWeaponCrowbar;
ConVar g_hWeaponElecGuitar;
ConVar g_hWeaponFireAxe;
ConVar g_hWeaponFryingPan;
ConVar g_hWeaponGolfClub;
ConVar g_hWeaponKnife;
ConVar g_hWeaponKatana;
ConVar g_hWeaponMachete;
ConVar g_hWeaponRiotShield;
ConVar g_hWeaponTonfa;

bool g_bSpawnedMelee;

int g_iMeleeClassCount = 0;
int g_iMeleeRandomSpawn[20];
int g_iRound = 2;

char g_sMeleeClass[16][32];

public Plugin myinfo =
{
    name = "Melee In The Saferoom",
    author = "N3wton",
    description = "Spawns a selection of melee weapons in the saferoom, at the start of each round.",
    version = VERSION
};

public void OnPluginStart()
{
    char GameName[12];
    GetGameFolderName(GameName, sizeof(GameName));
    if( !StrEqual(GameName, "left4dead2") )
        SetFailState( "Melee In The Saferoom is only supported on left 4 dead 2." );
        
    CreateConVar( "l4d2_MITSR_Version",     VERSION, "The version of Melee In The Saferoom"); 
    g_hEnabled              = CreateConVar( "l4d2_MITSR_Enabled",       "1", "Should the plugin be enabled"); 
    g_hWeaponRandom         = CreateConVar( "l4d2_MITSR_Random",        "0", "Spawn Random Weapons (1) or custom list (0)"); 
    g_hWeaponRandomAmount   = CreateConVar( "l4d2_MITSR_Amount",        "2", "Number of weapons to spawn if l4d2_MITSR_Random is 1"); 
    

    g_hWeaponBaseballBat    = CreateConVar( "l4d2_MITSR_BaseballBat",   "0", "Number of baseball bats to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponCricketBat     = CreateConVar( "l4d2_MITSR_CricketBat",    "0", "Number of cricket bats to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponCrowbar        = CreateConVar( "l4d2_MITSR_Crowbar",       "0", "Number of crowbars to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponElecGuitar     = CreateConVar( "l4d2_MITSR_ElecGuitar",    "0", "Number of electric guitars to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponFireAxe        = CreateConVar( "l4d2_MITSR_FireAxe",       "1", "Number of fireaxes to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponFryingPan      = CreateConVar( "l4d2_MITSR_FryingPan",     "0", "Number of frying pans to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponGolfClub       = CreateConVar( "l4d2_MITSR_GolfClub",      "0", "Number of golf clubs to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponKnife          = CreateConVar( "l4d2_MITSR_Knife",         "0", "Number of knifes to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponKatana         = CreateConVar( "l4d2_MITSR_Katana",        "1", "Number of katanas to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponMachete        = CreateConVar( "l4d2_MITSR_Machete",       "0", "Number of machetes to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponRiotShield     = CreateConVar( "l4d2_MITSR_RiotShield",    "0", "Number of riot shields to spawn (l4d2_MITSR_Random must be 0)");
    g_hWeaponTonfa          = CreateConVar( "l4d2_MITSR_Tonfa",         "0", "Number of tonfas to spawn (l4d2_MITSR_Random must be 0)");
    
    HookEvent( "round_start", Event_RoundStart );
    
    RegAdminCmd("sm_melee", Command_SMMelee, ADMFLAG_KICK, "Lists all melee weapons spawnable in current campaign" );
    

    //AutoExecConfig(true, "l4d2_melee_saferoom");
}

public Action Command_SMMelee(int client, int args)
{
    for( int i = 0; i < g_iMeleeClassCount; i++ )
    {
        PrintToChat( client, "%d : %s", i, g_sMeleeClass[i] );
    }
    return Plugin_Handled;
}

public void OnMapStart()
{
    PrecacheModel( "models/weapons/melee/v_bat.mdl", true );
    PrecacheModel( "models/weapons/melee/v_cricket_bat.mdl", true );
    PrecacheModel( "models/weapons/melee/v_crowbar.mdl", true );
    PrecacheModel( "models/weapons/melee/v_electric_guitar.mdl", true );
    PrecacheModel( "models/weapons/melee/v_fireaxe.mdl", true );
    PrecacheModel( "models/weapons/melee/v_frying_pan.mdl", true );
    PrecacheModel( "models/weapons/melee/v_golfclub.mdl", true );
    PrecacheModel( "models/weapons/melee/v_katana.mdl", true );
    PrecacheModel( "models/weapons/melee/v_machete.mdl", true );
    PrecacheModel( "models/weapons/melee/v_tonfa.mdl", true );
    PrecacheModel( "models/weapons/melee/v_riotshield.mdl", true );
	PrecacheModel( "models/weapons/melee/v_knife_t.mdl", true );
	PrecacheModel( "models/weapons/melee/v_shovel.mdl", true );
	PrecacheModel( "models/weapons/melee/v_pitchfork.mdl", true );
	
    PrecacheModel( "models/weapons/melee/w_bat.mdl", true );
    PrecacheModel( "models/weapons/melee/w_cricket_bat.mdl", true );
    PrecacheModel( "models/weapons/melee/w_crowbar.mdl", true );
    PrecacheModel( "models/weapons/melee/w_electric_guitar.mdl", true );
    PrecacheModel( "models/weapons/melee/w_fireaxe.mdl", true );
    PrecacheModel( "models/weapons/melee/w_frying_pan.mdl", true );
    PrecacheModel( "models/weapons/melee/w_golfclub.mdl", true );
    PrecacheModel( "models/weapons/melee/w_katana.mdl", true );
    PrecacheModel( "models/weapons/melee/w_machete.mdl", true );
    PrecacheModel( "models/weapons/melee/w_tonfa.mdl", true );

    
    PrecacheGeneric( "scripts/melee/baseball_bat.txt", true );
    PrecacheGeneric( "scripts/melee/cricket_bat.txt", true );
    PrecacheGeneric( "scripts/melee/crowbar.txt", true );
    PrecacheGeneric( "scripts/melee/electric_guitar.txt", true );
    PrecacheGeneric( "scripts/melee/fireaxe.txt", true );
    PrecacheGeneric( "scripts/melee/frying_pan.txt", true );
    PrecacheGeneric( "scripts/melee/golfclub.txt", true );
    PrecacheGeneric( "scripts/melee/katana.txt", true );
    PrecacheGeneric( "scripts/melee/machete.txt", true );
    PrecacheGeneric( "scripts/melee/tonfa.txt", true );
	PrecacheGeneric( "scripts/melee/riot_shield.txt", true );
	
    int index = CreateEntityByName("weapon_sniper_scout");
    if(index != -1)
    {
        DispatchSpawn(index);
        RemoveEntity(index);
    }
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if( !g_hEnabled.BoolValue ) 
        return Plugin_Continue;
    
    g_bSpawnedMelee = false;
    
    if( g_iRound == 2 && IsVersus() ) 
        g_iRound = 1; 
    else 
        g_iRound = 2;
    
    GetMeleeClasses();
    
    CreateTimer( 1.0, Timer_SpawnMelee );
    
    return Plugin_Continue;
}

public Action Timer_SpawnMelee( Handle timer )
{
    int client = GetInGameClient();

    if( client != 0 && !g_bSpawnedMelee )
    {
        float SpawnPosition[3], SpawnAngle[3];
        GetClientAbsOrigin( client, SpawnPosition );
        SpawnPosition[2] += 20.0; 
        SpawnAngle[0] = 90.0;
        
        if( g_hWeaponRandom.BoolValue )
        {
            int weaponAmount = g_hWeaponRandomAmount.IntValue;
            for(int i = 0; i < weaponAmount; i++)
            {
                int RandomMelee = GetRandomInt( 0, g_iMeleeClassCount-1 );
                if( IsVersus() && g_iRound == 2 ) 
                    RandomMelee = g_iMeleeRandomSpawn[i]; 
                SpawnMelee( g_sMeleeClass[RandomMelee], SpawnPosition, SpawnAngle );
                if( IsVersus() && g_iRound == 1 ) 
                    g_iMeleeRandomSpawn[i] = RandomMelee;
            }
            g_bSpawnedMelee = true;
        }
        else
        {
            SpawnCustomList( SpawnPosition, SpawnAngle );
            g_bSpawnedMelee = true;
        }
    }
    else
    {
        if( !g_bSpawnedMelee ) 
            CreateTimer( 1.0, Timer_SpawnMelee );
    }
    return Plugin_Stop;
}

void SpawnCustomList( float Position[3], float Angle[3] )
{
    char ScriptName[32];
    
    //Spawn Baseball Bats
    int batCount = g_hWeaponBaseballBat.IntValue;
    if( batCount > 0 )
    {
        for( int i = 0; i < batCount; i++ )
        {
            GetScriptName( "baseball_bat", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Cricket Bats
    int cricketBatCount = g_hWeaponCricketBat.IntValue;
    if( cricketBatCount > 0 )
    {
        for( int i = 0; i < cricketBatCount; i++ )
        {
            GetScriptName( "cricket_bat", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Crowbars
    int crowbarCount = g_hWeaponCrowbar.IntValue;
    if( crowbarCount > 0 )
    {
        for( int i = 0; i < crowbarCount; i++ )
        {
            GetScriptName( "crowbar", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Electric Guitars
    int guitarCount = g_hWeaponElecGuitar.IntValue;
    if( guitarCount > 0 )
    {
        for( int i = 0; i < guitarCount; i++ )
        {
            GetScriptName( "electric_guitar", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Fireaxes
    int axeCount = g_hWeaponFireAxe.IntValue;
    if( axeCount > 0 )
    {
        for( int i = 0; i < axeCount; i++ )
        {
            GetScriptName( "fireaxe", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Frying Pans
    int panCount = g_hWeaponFryingPan.IntValue;
    if( panCount > 0 )
    {
        for( int i = 0; i < panCount; i++ )
        {
            GetScriptName( "frying_pan", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Golfclubs
    int golfCount = g_hWeaponGolfClub.IntValue;
    if( golfCount > 0 )
    {
        for( int i = 0; i < golfCount; i++ )
        {
            GetScriptName( "golfclub", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Knifes
    int knifeCount = g_hWeaponKnife.IntValue;
    if( knifeCount > 0 )
    {
        for( int i = 0; i < knifeCount; i++ )
        {
            GetScriptName( "hunting_knife", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Katanas
    int katanaCount = g_hWeaponKatana.IntValue;
    if( katanaCount > 0 )
    {
        for( int i = 0; i < katanaCount; i++ )
        {
            GetScriptName( "katana", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Machetes
    int macheteCount = g_hWeaponMachete.IntValue;
    if( macheteCount > 0 )
    {
        for( int i = 0; i < macheteCount; i++ )
        {
            GetScriptName( "machete", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn RiotShields
    int shieldCount = g_hWeaponRiotShield.IntValue;
    if( shieldCount > 0 )
    {
        for( int i = 0; i < shieldCount; i++ )
        {
            GetScriptName( "riotshield", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
    
    //Spawn Tonfas
    int tonfaCount = g_hWeaponTonfa.IntValue;
    if( tonfaCount > 0 )
    {
        for( int i = 0; i < tonfaCount; i++ )
        {
            GetScriptName( "tonfa", ScriptName, sizeof(ScriptName) );
            SpawnMelee( ScriptName, Position, Angle );
        }
    }
}

void SpawnMelee( const char[] Class, float Position[3], float Angle[3] )
{
    float SpawnPosition[3], SpawnAngle[3];
    SpawnPosition = Position;
    SpawnAngle = Angle;
    
    SpawnPosition[0] += float( -10 + GetRandomInt( 0, 20 ) );
    SpawnPosition[1] += float( -10 + GetRandomInt( 0, 20 ) );
    SpawnPosition[2] += float( GetRandomInt( 0, 10 ) );
    SpawnAngle[1] = GetRandomFloat( 0.0, 360.0 );

    int MeleeSpawn = CreateEntityByName( "weapon_melee" );
    if(MeleeSpawn != -1)
    {
        DispatchKeyValue( MeleeSpawn, "melee_script_name", Class );
        DispatchSpawn( MeleeSpawn );
        TeleportEntity(MeleeSpawn, SpawnPosition, SpawnAngle, NULL_VECTOR );
    }
}

void GetMeleeClasses()
{
    int MeleeStringTable = FindStringTable( "MeleeWeapons" );
    if(MeleeStringTable != INVALID_STRING_TABLE)
    {
        g_iMeleeClassCount = GetStringTableNumStrings( MeleeStringTable );
        
        for( int i = 0; i < g_iMeleeClassCount; i++ )
        {
            ReadStringTable( MeleeStringTable, i, g_sMeleeClass[i], 32 );
        }
    }
}

void GetScriptName( const char[] Class, char[] ScriptName, int maxlength )
{
    for( int i = 0; i < g_iMeleeClassCount; i++ )
    {
        if( StrContains( g_sMeleeClass[i], Class, false ) == 0 )
        {
            strcopy( ScriptName, maxlength, g_sMeleeClass[i] );
            return;
        }
    }
    if(g_iMeleeClassCount > 0)
        strcopy( ScriptName, maxlength, g_sMeleeClass[0] );
}

int GetInGameClient()
{
    for( int x = 1; x <= MaxClients; x++ )
    {
        if( IsClientInGame( x ) && GetClientTeam( x ) == 2 )
        {
            return x;
        }
    }
    return 0;
}

bool IsVersus()
{
    char GameMode[32];
    ConVar gamemodeConvar = FindConVar( "mp_gamemode" );
    if(gamemodeConvar != null)
    {
        gamemodeConvar.GetString( GameMode, sizeof(GameMode) );
        if( StrContains( GameMode, "versus", false ) != -1 ) 
            return true;
    }
    return false;
}

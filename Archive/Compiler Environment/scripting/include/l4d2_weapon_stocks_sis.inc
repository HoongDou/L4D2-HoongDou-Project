/*
==============================================

About this Include:

The original version was created by the l4d competitive community (I do not know who is the original author).
This group has created and made public some of the most innovative and useful l4d2 code found anywhere.
Thank you for contributing so much to the broader l4d/l4d2 community!

Regarding this version, I've only removed some sections that were not applicable to the Smart Item Selector plugin.
A special thanks to Dragokas for converting this version to the new methodmap syntax, which also removed the multi-tags
that have not been supported in sourcemod for some time.

The source include is found here:
https://github.com/Attano/smplugins/blob/master/spechud/include/l4d2_weapon_stocks.inc

============================================================================
*/

#if defined l4d2_weapons_inc_
    #endinput
#endif
#define l4d2_weapons_inc_

#define GETWEAPONNAME(%0) (IsValidWeaponId(WeaponId:(%0)) ? (WeaponNames[view_as<int>(%0)]) : "")
#define GETMELEEWEAPONNAME(%0) (IsValidWeaponId(MeleeWeaponId:(%0)) ? (MeleeWeaponNames[view_as<int>(%0)]) : "")
#define GETMELEEWEAPONMODEL(%0) (HasValidWeaponModel(MeleeWeaponId:(%0)) ? (MeleeWeaponModels[view_as<int>(%0)]) : "")

// Weapon ID enumerations.
// These values are *NOT* arbitrary! 
// They are used in game as the weaponid for weapon_spawn entities
enum WeaponId
{
    WEPID_NONE,             // 0
    WEPID_PISTOL,           // 1
    WEPID_SMG,              // 2
    WEPID_PUMPSHOTGUN,      // 3
    WEPID_AUTOSHOTGUN,      // 4
    WEPID_RIFLE,            // 5
    WEPID_HUNTING_RIFLE,    // 6
    WEPID_SMG_SILENCED,     // 7
    WEPID_SHOTGUN_CHROME,   // 8
    WEPID_RIFLE_DESERT,     // 9
    WEPID_SNIPER_MILITARY,  // 10
    WEPID_SHOTGUN_SPAS,     // 11
    WEPID_FIRST_AID_KIT,    // 12
    WEPID_MOLOTOV,          // 13
    WEPID_PIPE_BOMB,        // 14
    WEPID_PAIN_PILLS,       // 15
    WEPID_GASCAN,           // 16
    WEPID_PROPANE_TANK,     // 17
    WEPID_OXYGEN_TANK,      // 18
    WEPID_MELEE,            // 19
    WEPID_CHAINSAW,         // 20
    WEPID_GRENADE_LAUNCHER, // 21
    WEPID_AMMO_PACK,        // 22
    WEPID_ADRENALINE,       // 23
    WEPID_DEFIBRILLATOR,    // 24
    WEPID_VOMITJAR,         // 25
    WEPID_RIFLE_AK47,       // 26
    WEPID_GNOME_CHOMPSKI,   // 27
    WEPID_COLA_BOTTLES,     // 28
    WEPID_FIREWORKS_BOX,    // 29
    WEPID_INCENDIARY_AMMO,  // 30
    WEPID_FRAG_AMMO,        // 31
    WEPID_PISTOL_MAGNUM,    // 32
    WEPID_SMG_MP5,          // 33
    WEPID_RIFLE_SG552,      // 34
    WEPID_SNIPER_AWP,       // 35
    WEPID_SNIPER_SCOUT,     // 36
    WEPID_RIFLE_M60,        // 37
    WEPID_TANK_CLAW,        // 38
    WEPID_HUNTER_CLAW,      // 39
    WEPID_CHARGER_CLAW,     // 40
    WEPID_BOOMER_CLAW,      // 41
    WEPID_SMOKER_CLAW,      // 42
    WEPID_SPITTER_CLAW,     // 43
    WEPID_JOCKEY_CLAW,      // 44
    WEPID_MACHINEGUN,       // 45
    WEPID_VOMIT,            // 46
    WEPID_SPLAT,            // 47
    WEPID_POUNCE,           // 48
    WEPID_LOUNGE,           // 49
    WEPID_PULL,             // 50
    WEPID_CHOKE,            // 51
    WEPID_ROCK,             // 52
    WEPID_PHYSICS,          // 53
    WEPID_AMMO,             // 54
    WEPID_UPGRADE_ITEM      // 55
};

// These values are arbitrary
enum MeleeWeaponId 
{
    WEPID_MELEE_NONE,		//0
    WEPID_KNIFE,			//1
    WEPID_BASEBALL_BAT,		//2
    WEPID_CRICKET_BAT,		//3
    WEPID_CROWBAR,			//4
    WEPID_ELECTRIC_GUITAR,	//5
    WEPID_FIREAXE,			//6
    WEPID_FRYING_PAN,		//7
    WEPID_GOLF_CLUB,		//8
    WEPID_KATANA,			//9
    WEPID_MACHETE,			//10
    WEPID_RIOT_SHIELD,		//11
    WEPID_TONFA				//12
};

// Weapon names for each of the weapons, used in identification.
char WeaponNames[WeaponId][] =
{
    "weapon_none", "weapon_pistol", "weapon_smg",                                            // 0
    "weapon_pumpshotgun", "weapon_autoshotgun", "weapon_rifle",                              // 3
    "weapon_hunting_rifle", "weapon_smg_silenced", "weapon_shotgun_chrome",                  // 6
    "weapon_rifle_desert", "weapon_sniper_military", "weapon_shotgun_spas",                  // 9
    "weapon_first_aid_kit", "weapon_molotov", "weapon_pipe_bomb",                            // 12
    "weapon_pain_pills", "weapon_gascan", "weapon_propanetank",                              // 15
    "weapon_oxygentank", "weapon_melee", "weapon_chainsaw",                                  // 18
    "weapon_grenade_launcher", "weapon_ammo_pack", "weapon_adrenaline",                      // 21
    "weapon_defibrillator", "weapon_vomitjar", "weapon_rifle_ak47",                          // 24
    "weapon_gnome", "weapon_cola_bottles", "weapon_fireworkcrate",                           // 27
    "weapon_upgradepack_incendiary", "weapon_upgradepack_explosive", "weapon_pistol_magnum", // 30
    "weapon_smg_mp5", "weapon_rifle_sg552", "weapon_sniper_awp",                             // 33
    "weapon_sniper_scout", "weapon_rifle_m60", "weapon_tank_claw",                           // 36
    "weapon_hunter_claw", "weapon_charger_claw", "weapon_boomer_claw",                       // 39
    "weapon_smoker_claw", "weapon_spitter_claw", "weapon_jockey_claw",                       // 42
    "weapon_machinegun", "vomit", "splat",                                                   // 45
    "pounce", "lounge", "pull",                                                              // 48
    "choke", "rock", "physics",                                                              // 51
    "ammo", "upgrade_item"                                                                   // 54
};

// Internal names for melee weapons
char MeleeWeaponNames[MeleeWeaponId][] =
{
    "",
    "knife",
    "baseball_bat",
    "cricket_bat",
    "crowbar",
    "electric_guitar",
    "fireaxe",
    "frying_pan",
    "golfclub",
    "katana",
    "machete",
    "riotshield",
    "tonfa"
};

char MeleeWeaponModels[MeleeWeaponId][] =
{
    "",
    "/w_models/weapons/w_knife_t.mdl",
    "/weapons/melee/w_bat.mdl",
    "/weapons/melee/w_cricket_bat.mdl",
    "/weapons/melee/w_crowbar.mdl",
    "/weapons/melee/w_electric_guitar.mdl",
    "/weapons/melee/w_fireaxe.mdl",
    "/weapons/melee/w_frying_pan.mdl",
    "/weapons/melee/w_golfclub.mdl",
    "/weapons/melee/w_katana.mdl",
    "/weapons/melee/w_machete.mdl",
    "/weapons/melee/w_riotshield.mdl",
    "/weapons/melee/w_tonfa.mdl"
};

enum L4D2WeaponSlot
{
    L4D2WeaponSlot_Primary,
    L4D2WeaponSlot_Secondary,
    L4D2WeaponSlot_Throwable,
    L4D2WeaponSlot_HeavyHealthItem,
    L4D2WeaponSlot_LightHealthItem
};

StringMap hWeaponNamesTrie;
StringMap hMeleeWeaponNamesTrie;
StringMap hMeleeWeaponModelsTrie;

stock void InitWeaponNamesTrie()
{
    hWeaponNamesTrie = CreateTrie();
    for(int i = 0; i < view_as<int>(WeaponId); i++)
    {
		hWeaponNamesTrie.SetValue(WeaponNames[i], i);
    }

    hMeleeWeaponNamesTrie = CreateTrie();
    hMeleeWeaponModelsTrie = CreateTrie();
    for (int i = 0; i < view_as<int>(MeleeWeaponId); ++i)
    {
		hMeleeWeaponNamesTrie.SetValue(MeleeWeaponNames[i], i);
		hMeleeWeaponModelsTrie.SetString(MeleeWeaponModels[i], MeleeWeaponNames[i]);
	}
}

/**
 * Tries to look up a WeaponId for a given Weapon Name.
 *
 * @param weaponName    Weapon name string to look up Id from
 * @return                The corresponding WeaponId if found, else WEPID_NONE
 */
stock WeaponId WeaponNameToId(const char[] weaponName)
{
    WeaponId id;
    if(hWeaponNamesTrie == null)
    {
        InitWeaponNamesTrie();
    }
    if(hWeaponNamesTrie.GetValue(weaponName, id))
    {
        return id;
    }
    return WEPID_NONE;
}

/**
 * Identifies a weapon spawn or weapon entity as a WeaponID
 * @remark Should work on most weapon ents--even spawns, singles, held, etc.
 *
 * @param entity        Index of entity to identify
 * @return WeaponID for the entity if it is a weapon, WEPID_NONE otherwise
 */
stock WeaponId IdentifyWeapon(int entity)
{
    if(!entity || !IsValidEntity(entity) || !IsValidEdict(entity))
    {
        return WEPID_NONE;
    }
    char class[64];
    if(!GetEdictClassname(entity, class, sizeof(class)))
    {
        return WEPID_NONE;
    }

    if(StrEqual(class, "weapon_spawn"))
    {
        return view_as<WeaponId>(GetEntProp(entity,Prop_Send,"m_weaponID"));
    }

    int len = strlen(class);
    if(len-6 > 0 && StrEqual(class[len-6], "_spawn"))
    {
        class[len-6]='\0';
        return WeaponNameToId(class);
    }
    
    return WeaponNameToId(class);
}

// Helper function used for getting an entity's internal melee name
stock bool GetMeleeWeaponNameFromEntity(int entity, char[] buffer, int length) {
    char classname[64];
    if ( !GetEdictClassname(entity, classname, sizeof(classname)))
    {
        return false;
    }

    if (StrEqual(classname, "weapon_melee_spawn"))
    {
        if (hMeleeWeaponModelsTrie == null)
        {
            InitWeaponNamesTrie();
        }

        char sModelName[128];
        GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

        // Strip models directory
        if (strncmp(sModelName, "models/", 7, false) == 0)
        {
            strcopy(sModelName, sizeof(sModelName), sModelName[6]);
        }

        if (hMeleeWeaponModelsTrie.GetString(sModelName, buffer, length))
        {
            return true;
        }
        return false;
    }
    else if (StrEqual(classname, "weapon_melee"))
    {
        GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", buffer, length);
        return true;
    }

    return false;
}

/**
 * Identifies a melee weapon spawn or weapon entity as a MeleeWeaponId
 * @remark Should work on most weapon ents--even spawns, singles, held, etc.
 *
 * @param entity        Index of entity to identify
 * @return MeleeWeaponId for the entity if it is a weapon, WEPID_MELEE_NONE otherwise
 */

stock MeleeWeaponId IdentifyMeleeWeapon(int entity)
{
    if (IdentifyWeapon(entity) != WEPID_MELEE)
    {
        return WEPID_MELEE_NONE;
    }

    char sName[128];
    if (! GetMeleeWeaponNameFromEntity(entity, sName, sizeof(sName)))
    {
        return WEPID_MELEE_NONE;
    }

    if (hMeleeWeaponNamesTrie == null)
    {
        InitWeaponNamesTrie();
    }

    int id;
    if(hMeleeWeaponNamesTrie.GetValue(sName, id))
    {
        return view_as<MeleeWeaponId>(id);
    }
    return WEPID_MELEE_NONE;
}
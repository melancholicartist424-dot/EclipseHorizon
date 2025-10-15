using System.Collections;
using UnityEngine;

// ToolsAndAbilities handles the player's weapons, aiming, interaction and
// class configuration.  It coordinates with CharacterCore for HUD and
// class state.  This version includes modifications so that shots
// fired from the player can damage ByugzAI enemies correctly via the
// Damage(GameObject, float) overload, passing this component’s
// GameObject as the source of damage.  All other behaviour (recoil,
// aiming, cooldowns, pick throwing) remains unchanged from the
// original user code.
public class ToolsAndAbilities : MonoBehaviour
{
    CharacterCore core;

    #region Masks
    [SerializeField] LayerMask Shootable;
    [SerializeField] LayerMask InteractableLayer;
    [SerializeField] LayerMask EnvironmentMask;
    #endregion

    // --------- CLASS CONFIG DATA FOR INSPECTOR ----------
    [System.Serializable]
    public struct ClassConfig
    {
        [Header("Weapons / Ammo")]
        public float primaryDamage;
        public float secondaryDamage;
        public int clipSizePrimary;
        public int clipSizeSecondary;
        public int reservePrimary;
        public int reserveSecondary;
        public float cooldownPrimary;
        public float cooldownSecondary;

        [Header("Aiming / FOV")]
        public bool aimPressIsNegative;   // true: Aim axis < 0, false: > 0
        [Tooltip("ADS zoom multiplier: 1.0 = no zoom, 0.8 = mild zoom, 0.6 = strong zoom")]
        [Range(0.3f, 1f)] public float adsFOV;     // now treated as % of hip FOV

        [Header("Aim Cone / Range")]
        public float hipAimRadius;
        public float hipAimRange;
        public float adsAimRadius;
        public float adsAimRange;

        [Header("Spread / Recoil")]
        public float hipSpread;
        public float adsSpread;
        public float recoilPitch;
        public float recoilYawJitter;

        [Header("Pick")]
        public GameObject pickPrefab;
    }

    [Header("Class Configs (edit here per class)")]
    public ClassConfig civilianConfig;
    public ClassConfig soldierConfig;
    public ClassConfig engineerConfig;
    public ClassConfig supportConfig;
    public ClassConfig scoutConfig;

    #region Runtime weapon state
    bool piercing = false;
    int ammoReserveW;
    int currentAmmoW;
    [SerializeField] int clipSizeW = 20;
    int ammoReserveT;
    int currentAmmoT;
    [SerializeField] int clipSizeT = 5;
    float bulletCoolDownWCurrent = 0f;
    [SerializeField] float bulletCoolDownWStart = .2f;
    float bulletCoolDownTCurrent = 0f;
    [SerializeField] float bulletCoolDownTStart = 2f;
    [SerializeField] float primaryDamage = 20f;
    [SerializeField] float secondaryDamage = 20f;
    #endregion

    #region Aim / Zoom
    float aimRadius;
    float aimRange;

    [Header("Zoom / Aim Defaults (hip only)")]
    [SerializeField] float hipFOV = 75f;
    [SerializeField] float zoomLerpSpeed = 10f;

    [SerializeField] float hipAimRadius = 1.0f;
    [SerializeField] float hipAimRange = 400f;
    [SerializeField] float adsAimRadius_Tight = 0.1f;
    [SerializeField] float adsAimRange_Tight = 400f;

    [Header("Spread / Recoil (overridden by config)")]
    [SerializeField] float hipSpread = 0.02f;
    [SerializeField] float adsSpread = 0.005f;
    [SerializeField] float recoilPitch = 0.3f;
    [SerializeField] float recoilYawJitter = 0.2f;

    float targetFOV;
    bool isZooming = false;
    bool aimPressIsNegative = true;
    float adsFOVActive = 52f; // now computed as hipFOV * multiplier
    #endregion

    #region Picks
    [Header("Throw Settings")]
    [SerializeField] Transform throwOrigin;
    [SerializeField] float throwForce = 12f;
    [SerializeField] float throwArcUp = 2f;
    [SerializeField] float pickCooldown = 0.8f;
    [SerializeField] int maxPicks = 3;

    GameObject activePickPrefab;
    int currentPicks;
    float pickTimer = 0f;
    #endregion

    #region FX / Tags
    [Header("FX")]
    [SerializeField] GameObject bloodFXPrefab;

    [Header("Blood Spawn Tags (any match)")]
    [SerializeField] string[] bloodTags = new string[] { "Enemy", "Bleeds", "Flesh" };
    #endregion

    #region State
    bool holdingPrimary = true;
    bool isSneaking = false;
    CharacterCore.ChosenClass lastConfiguredClass;
    #endregion

    void Start()
    {
        core = GetComponent<CharacterCore>();

        currentAmmoW = Mathf.Min(clipSizeW, 100);
        currentAmmoT = Mathf.Min(clipSizeT, 100);
        currentPicks = maxPicks;

        if (core && core.PlayerCamera)
        {
            if (Mathf.Approximately(hipFOV, 75f))
                hipFOV = core.PlayerCamera.fieldOfView;
            targetFOV = hipFOV;
        }

        aimRadius = hipAimRadius;
        aimRange = hipAimRange;

        ConfigureForClass(core ? core._chosenClass : CharacterCore.ChosenClass.civilian);
        lastConfiguredClass = core ? core._chosenClass : CharacterCore.ChosenClass.civilian;

        if (core) core.OnClassChange += ConfigureForClass;

        UpdateCoreClipSize();
        UpdateCoreAmmo();
    }

    void OnDestroy()
    {
        if (core) core.OnClassChange -= ConfigureForClass;
    }

    void Update()
    {
        if (!core || !core.PlayerCamera) return;

        TickCooldowns();

        // If class changed at runtime, reapply config
        if (core._chosenClass != lastConfiguredClass)
        {
            ConfigureForClass(core._chosenClass);
            lastConfiguredClass = core._chosenClass;
        }

        // Swap weapons
        if (Input.GetButtonDown("WeaponSwap"))
        {
            holdingPrimary = !holdingPrimary;
            UpdateCoreClipSize();
            UpdateCoreAmmo();
        }

        // Sneak toggle
        if (Input.GetButtonDown("Sneak Toggle")) isSneaking = !isSneaking;
        if (Input.GetButtonDown("Interact")) TryInteract();
        if (Input.GetButtonDown("Reload")) Reload();

        // Throw pick
        if (Input.GetButtonDown("Pick") && currentPicks > 0 && pickTimer <= 0f && activePickPrefab)
        {
            ThrowPick(activePickPrefab);
            currentPicks--;
            pickTimer = pickCooldown;
        }

        // Aim input: axis sign depends on config
        float aimAxis = Input.GetAxis("Aim");
        bool aimPressed = aimPressIsNegative ? (aimAxis < 0f) : (aimAxis > 0f);
        ApplyAim(aimPressed, hipFOV, adsFOVActive);

        // Trigger input: negative axis indicates fire
        if (Input.GetAxis("Trigger") < 0)
            HandleShooting(primaryDamage, secondaryDamage);

        // Smoothly adjust FOV when zooming
        LerpZoom();
    }

    // ---------------- CONFIGURE PER CLASS ----------------
    void ConfigureForClass(CharacterCore.ChosenClass cls)
    {
        ClassConfig cfg = GetConfig(cls);

        primaryDamage = cfg.primaryDamage;
        secondaryDamage = cfg.secondaryDamage;
        clipSizeW = Mathf.Max(0, cfg.clipSizePrimary);
        clipSizeT = Mathf.Max(0, cfg.clipSizeSecondary);
        ammoReserveW = Mathf.Max(0, cfg.reservePrimary);
        ammoReserveT = Mathf.Max(0, cfg.reserveSecondary);
        bulletCoolDownWStart = Mathf.Max(0.01f, cfg.cooldownPrimary);
        bulletCoolDownTStart = Mathf.Max(0.01f, cfg.cooldownSecondary);

        hipAimRadius = Mathf.Max(0f, cfg.hipAimRadius);
        hipAimRange = Mathf.Max(0f, cfg.hipAimRange);
        adsAimRadius_Tight = Mathf.Max(0f, cfg.adsAimRadius);
        adsAimRange_Tight = Mathf.Max(0f, cfg.adsAimRange);

        hipSpread = Mathf.Max(0f, cfg.hipSpread);
        adsSpread = Mathf.Max(0f, cfg.adsSpread);
        recoilPitch = cfg.recoilPitch;
        recoilYawJitter = cfg.recoilYawJitter;

        aimPressIsNegative = cfg.aimPressIsNegative;

        // ADS FOV is a multiplier of hip FOV (1.0 = no zoom)
        adsFOVActive = hipFOV * Mathf.Clamp(cfg.adsFOV, 0.3f, 1f);

        activePickPrefab = cfg.pickPrefab;

        if (currentAmmoW > clipSizeW) currentAmmoW = clipSizeW;
        if (currentAmmoT > clipSizeT) currentAmmoT = clipSizeT;

        UpdateCoreClipSize();
        UpdateCoreAmmo();
    }

    ClassConfig GetConfig(CharacterCore.ChosenClass cls)
    {
        return cls switch
        {
            CharacterCore.ChosenClass.soldier => soldierConfig,
            CharacterCore.ChosenClass.engineer => engineerConfig,
            CharacterCore.ChosenClass.support => supportConfig,
            CharacterCore.ChosenClass.scout => scoutConfig,
            _ => civilianConfig
        };
    }

    // ---------------- RUNTIME ----------------
    void TickCooldowns()
    {
        if (bulletCoolDownWCurrent > 0f) bulletCoolDownWCurrent -= Time.deltaTime;
        if (bulletCoolDownTCurrent > 0f) bulletCoolDownTCurrent -= Time.deltaTime;
        if (pickTimer > 0f) pickTimer -= Time.deltaTime;

        bulletCoolDownWCurrent = Mathf.Max(0f, bulletCoolDownWCurrent);
        bulletCoolDownTCurrent = Mathf.Max(0f, bulletCoolDownTCurrent);
        pickTimer = Mathf.Max(0f, pickTimer);
    }

    void LerpZoom()
    {
        float current = core.PlayerCamera.fieldOfView;
        float next = Mathf.Lerp(current, targetFOV, Time.deltaTime * zoomLerpSpeed);
        core.PlayerCamera.fieldOfView = next;
    }

    void ApplyAim(bool pressed, float hip, float ads)
    {
        isZooming = pressed;
        targetFOV = isZooming ? ads : hip;
        aimRadius = isZooming ? adsAimRadius_Tight : hipAimRadius;
        aimRange = isZooming ? adsAimRange_Tight : hipAimRange;
    }

    void TryInteract()
    {
        float interactRange = 3f;
        if (Physics.Raycast(core.PlayerCamera.transform.position, core.PlayerCamera.transform.forward,
            out RaycastHit hit, interactRange, InteractableLayer, QueryTriggerInteraction.Ignore))
        {
            IInteractable interactable = hit.collider.GetComponentInParent<IInteractable>();
            if (interactable != null) interactable.Interact(gameObject);
        }
    }

    // ---------------- SHOOTING ----------------
    void HandleShooting(float dmgPrimary, float dmgSecondary)
    {
        if (holdingPrimary)
        {
            if (piercing) piercing = false;
            if (currentAmmoW > 0 && bulletCoolDownWCurrent <= 0f)
            {
                FireShot(dmgPrimary);
                currentAmmoW--;
                bulletCoolDownWCurrent = bulletCoolDownWStart;
                DoRecoilKick();
                UpdateCoreAmmo();
            }
            else if (currentAmmoW == 0 && ammoReserveW > 0) Reload();
        }
        else
        {
            if (!piercing) piercing = true;
            if (currentAmmoT > 0 && bulletCoolDownTCurrent <= 0f)
            {
                FireShot(dmgSecondary);
                currentAmmoT--;
                bulletCoolDownTCurrent = bulletCoolDownTStart;
                DoRecoilKick();
                UpdateCoreAmmo();
            }
            else if (currentAmmoT == 0 && ammoReserveT > 0) Reload();
        }
    }

    // FireShot casts rays/spherecasts and processes hits.  When a ByugzAI
    // is hit the shooter GameObject is passed so that aggro can be
    // propagated.  Non-Byugz enemies implement EnemyLife which uses
    // Damage(float) instead.
    void FireShot(float dmg)
    {
        Vector3 origin = core.PlayerCamera.transform.position;
        Vector3 dir = core.PlayerCamera.transform.forward;

        float spreadRad = isZooming ? adsSpread : hipSpread;
        float spreadDeg = spreadRad * Mathf.Rad2Deg;
        dir = Quaternion.Euler(Random.Range(-spreadDeg, spreadDeg),
                               Random.Range(-spreadDeg, spreadDeg), 0f) * dir;

        Ray ray = new Ray(origin, dir);
        int mask = Shootable | EnvironmentMask;

        if (!piercing)
        {
            if (Physics.SphereCast(ray, aimRadius, out RaycastHit hit, aimRange, mask))
                ProcessHit(hit, dmg);
        }
        else
        {
            var hits = Physics.SphereCastAll(ray, aimRadius, aimRange, mask);
            System.Array.Sort(hits, (a, b) => a.distance.CompareTo(b.distance));
            foreach (var h in hits) ProcessHit(h, dmg);
        }
    }

    // ProcessHit applies damage to both generic EnemyLife and the more
    // complex ByugzAI.  For ByugzAI we call Damage(GameObject source,
    // float dmg) so that the enemy knows who shot it; otherwise we call
    // the EnemyLife.Damage(float) overload.
    void ProcessHit(RaycastHit hit, float dmg)
    {
        // Standard enemy damage
        if (hit.transform.TryGetComponent(out EnemyLife life))
            life.Damage(dmg);

        // NEW: If this is a Byugz, use Damage(GameObject source, float dmg)
        if (hit.transform.TryGetComponent(out ByugzAI byugz))
        {
            // Pass this tool's GameObject (the shooter) as the source
            byugz.Damage(gameObject, dmg);
        }

        // Blood effect
        if (ShouldSpawnBloodFromTags(hit.transform))
            SpawnBlood(hit);
    }

    bool ShouldSpawnBloodFromTags(Transform t)
    {
        Transform cur = t;
        int steps = 0;
        while (cur != null && steps < 4)
        {
            foreach (var tag in bloodTags)
                if (!string.IsNullOrEmpty(tag) && cur.CompareTag(tag)) return true;
            cur = cur.parent; steps++;
        }
        return false;
    }

    void SpawnBlood(RaycastHit hit)
    {
        if (!bloodFXPrefab) return;
        var fx = Instantiate(bloodFXPrefab, hit.point, Quaternion.LookRotation(hit.normal));
        var auto = fx.AddComponent<AutoDestroyParticle>();
        auto.lifetime = 2f;
    }

    void Reload()
    {
        if (holdingPrimary)
        {
            if (currentAmmoW < clipSizeW && ammoReserveW > 0)
            {
                int need = clipSizeW - currentAmmoW;
                int give = Mathf.Min(need, ammoReserveW);
                currentAmmoW += give;
                ammoReserveW -= give;
                UpdateCoreAmmo();
            }
        }
        else
        {
            if (currentAmmoT < clipSizeT && ammoReserveT > 0)
            {
                int need = clipSizeT - currentAmmoT;
                int give = Mathf.Min(need, ammoReserveT);
                currentAmmoT += give;
                ammoReserveT -= give;
                UpdateCoreAmmo();
            }
        }
    }

    void ThrowPick(GameObject prefab)
    {
        if (!prefab || !core || !core.PlayerCamera) return;
        Transform origin = (throwOrigin != null) ? throwOrigin : core.PlayerCamera.transform;

        GameObject go = Instantiate(prefab, origin.position + origin.forward * 0.3f, origin.rotation);
        if (!go.TryGetComponent<Rigidbody>(out var rb))
            rb = go.AddComponent<Rigidbody>();

        rb.useGravity = true;
        rb.collisionDetectionMode = CollisionDetectionMode.ContinuousDynamic;
        rb.linearVelocity = Vector3.zero;

        Vector3 dir = origin.forward + Vector3.up * (throwArcUp * 0.1f);
        rb.AddForce(dir.normalized * throwForce, ForceMode.VelocityChange);
    }

    void DoRecoilKick()
    {
        var cam = core.PlayerCamera.transform;
        cam.localRotation *= Quaternion.Euler(
            -recoilPitch,
            Random.Range(-recoilYawJitter, recoilYawJitter),
            0f
        );
    }

    // --- HUD sync ---
    void UpdateCoreAmmo()
    {
        if (!core) return;
        if (holdingPrimary)
        {
            core.CurrentAmmo = currentAmmoW;
            core.AmmoReserve = ammoReserveW;
        }
        else
        {
            core.CurrentAmmo = currentAmmoT;
            core.AmmoReserve = ammoReserveT;
        }
    }

    void UpdateCoreClipSize()
    {
        if (!core) return;
        core.ClipSize = holdingPrimary ? clipSizeW : clipSizeT;
    }
}

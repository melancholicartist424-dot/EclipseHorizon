using UnityEngine;

[RequireComponent(typeof(CharacterCore))]
public class PlayerShieldSystem : MonoBehaviour
{
    CharacterCore core;

    [Header("Shield Regeneration")]
    [SerializeField] float regenRate = 10f;           // shield per second
    [SerializeField] float regenDelay = 3f;           // seconds after damage before regen
    [SerializeField] float powerCostPerShield = 0.2f; // power cost per 1 shield point
    [SerializeField] float passivePowerRegen = 0f;    // optional energy recharge/sec
    [SerializeField] bool debug = false;

    float lastHitTime;
    float prevShield;

    void Awake()
    {
        core = GetComponent<CharacterCore>();
        prevShield = core.CurrentShield;
        lastHitTime = -regenDelay; // start “ready to regen” but timer works correctly
    }

    void Update()
    {
        DetectDamage();
        HandlePowerRegen();
        HandleShieldRegen();
    }

    void DetectDamage()
    {
        // if the shield value drops, mark a hit
        if (core.CurrentShield < prevShield - 0.001f)
        {
            lastHitTime = Time.time;
            if (debug) Debug.Log($"[Shield] Took hit at {Time.time}");
        }

        prevShield = core.CurrentShield;
    }

    void HandlePowerRegen()
    {
        if (passivePowerRegen > 0f && core.CurrentPower < core.MaxPower)
        {
            core.CurrentPower = Mathf.Min(core.MaxPower, core.CurrentPower + passivePowerRegen * Time.deltaTime);
        }
    }

    void HandleShieldRegen()
    {
        // wait the proper cooldown before regenerating
        if (Time.time - lastHitTime < regenDelay) return;
        if (core.CurrentShield >= core.MaxShield) return;
        if (core.CurrentPower <= 0f) return;

        float regenAmount = regenRate * Time.deltaTime;
        float requiredPower = regenAmount * powerCostPerShield;

        // ensure we can afford at least a tiny tick
        if (core.CurrentPower >= requiredPower)
        {
            core.CurrentShield += regenAmount;
            core.CurrentPower -= requiredPower;

            // clamp
            if (core.CurrentShield > core.MaxShield) core.CurrentShield = core.MaxShield;
            if (core.CurrentPower < 0f) core.CurrentPower = 0f;

            if (debug) Debug.Log($"[Shield] Regen {regenAmount:F2} | Shield:{core.CurrentShield:F1}/{core.MaxShield:F1}");
        }
    }

    // This is the function enemies should call — ensures the timer resets.
    public void TakeDamage(float dmg)
    {
        lastHitTime = Time.time;

        if (core.CurrentShield > 0)
        {
            core.CurrentShield -= dmg;
            if (core.CurrentShield < 0)
            {
                float overflow = -core.CurrentShield;
                core.CurrentShield = 0;
                core.CurrentHealth -= overflow;
            }
        }
        else
        {
            core.CurrentHealth -= dmg;
        }

        core.CurrentHealth = Mathf.Max(0f, core.CurrentHealth);
        prevShield = core.CurrentShield;

        if (debug) Debug.Log($"[Shield] Damage {dmg:F1} → Shield:{core.CurrentShield:F1}");
    }
}

// CharacterCore.cs
// Pure data table: holds values and fires events. No gameplay logic.

using System;
using UnityEngine;

public class CharacterCore : MonoBehaviour
{
    public static CharacterCore Instance { get; private set; }

    public enum ChosenClass { civilian, soldier, support, engineer, scout };
    public enum MovementMode { Ground, Jump, Fall, Climb, Line };

    public LayerMask groundLayer;

    #region Events
    public event Action<float> OnHealthSet;
    public event Action<bool> OnGroundSet;
    public event Action<bool> OnSprintSet;
    public event Action<bool> OnJumpSet;
    public event Action<bool> OnSneakSet;
    public event Action<bool> OnZoomSet;
    public event Action<ChosenClass> OnClassChange;
    public event Action<bool> OnAliveStatusSet;

    // Ammo & clip size events
    public event Action<int, int> OnAmmoChanged;   // (current, reserve)
    public event Action<int> OnClipSizeChanged;    // active weapon clip size (for HUD digits)

    // Shield & Power events
    public event Action<float, float> OnShieldChanged; // (current, max)
    public event Action<float, float> OnPowerChanged;  // (current, max)
    #endregion

    #region Unity Components
    public Rigidbody Rb { get; private set; }
    public Animator Anim { get; private set; }
    [SerializeField] public Camera PlayerCamera;
    [SerializeField] public Camera MiniMapCamera;
    #endregion

    #region Class & Movement
    [SerializeField] ChosenClass chosenClass_ = ChosenClass.civilian;
    public ChosenClass _chosenClass
    {
        get => chosenClass_;
        set
        {
            if (chosenClass_ == value) return;
            chosenClass_ = value;
            OnClassChange?.Invoke(chosenClass_);
        }
    }

    MovementMode movementMode_ = MovementMode.Ground;
    public MovementMode _movementMode
    {
        get => movementMode_;
        set { if (movementMode_ != value) movementMode_ = value; }
    }
    #endregion

    #region Health (data only)
    private float _currentHealth;
    public float CurrentHealth
    {
        get => _currentHealth;
        set
        {
            if (Mathf.Approximately(_currentHealth, value)) return;
            _currentHealth = value;
            OnHealthSet?.Invoke(_currentHealth);
        }
    }
    public float MaxHealth { get; set; } = 100f;
    #endregion

    #region Character booleans
    bool _sneaking = false;
    public bool Sneaking { get => _sneaking; set { if (_sneaking == value) return; _sneaking = value; OnSneakSet?.Invoke(_sneaking); } }

    bool _zooming = false;
    public bool Zooming { get => _zooming; set { if (_zooming == value) return; _zooming = value; OnZoomSet?.Invoke(_zooming); } }

    bool _grounded = false;
    public bool Grounded { get => _grounded; set { if (_grounded == value) return; _grounded = value; OnGroundSet?.Invoke(_grounded); } }

    bool _jumping = false;
    public bool Jumping { get => _jumping; set { if (_jumping == value) return; _jumping = value; OnJumpSet?.Invoke(_jumping); } }

    bool _sprinting = false;
    public bool Sprinting { get => _sprinting; set { if (_sprinting == value) return; _sprinting = value; OnSprintSet?.Invoke(_sprinting); } }

    private bool _isAlive;
    public bool IsAlive { get => _isAlive; set { if (_isAlive == value) return; _isAlive = value; OnAliveStatusSet?.Invoke(_isAlive); } }
    #endregion

    #region Ammo (data only)
    private int _currentAmmo;
    public int CurrentAmmo
    {
        get => _currentAmmo;
        set
        {
            if (_currentAmmo == value) return;
            _currentAmmo = value;
            OnAmmoChanged?.Invoke(_currentAmmo, _ammoReserve);
        }
    }

    private int _ammoReserve;
    public int AmmoReserve
    {
        get => _ammoReserve;
        set
        {
            if (_ammoReserve == value) return;
            _ammoReserve = value;
            OnAmmoChanged?.Invoke(_currentAmmo, _ammoReserve);
        }
    }

    private int _clipSize;
    public int ClipSize
    {
        get => _clipSize;
        set
        {
            if (_clipSize == value) return;
            _clipSize = value;
            OnClipSizeChanged?.Invoke(_clipSize);
        }
    }

    // HUD policy for reserve padding (default 4; HUD clamps 1..4)
    private int _reserveDigits = 4;
    public int ReserveDigits
    {
        get => _reserveDigits;
        set => _reserveDigits = Mathf.Clamp(value, 1, 4);
    }
    #endregion

    #region Shield / Power (data only)
    private float _currentShield;
    public float CurrentShield
    {
        get => _currentShield;
        set
        {
            if (Mathf.Approximately(_currentShield, value)) return;
            _currentShield = value;
            OnShieldChanged?.Invoke(_currentShield, MaxShield);
        }
    }
    public float MaxShield { get; set; } = 100f;

    private float _currentPower;
    public float CurrentPower
    {
        get => _currentPower;
        set
        {
            if (Mathf.Approximately(_currentPower, value)) return;
            _currentPower = value;
            OnPowerChanged?.Invoke(_currentPower, MaxPower);
        }
    }
    public float MaxPower { get; set; } = 100f;
    #endregion

    private void Awake()
    {
        if (Instance != null && Instance != this) { Destroy(gameObject); return; }
        Instance = this;

        Rb = GetComponent<Rigidbody>();
        Anim = GetComponent<Animator>();

        _currentHealth = MaxHealth;
        _isAlive = true;

        _currentAmmo = 0;
        _ammoReserve = 0;
        _clipSize = 0;
        _reserveDigits = 4;

        _currentShield = MaxShield;
        _currentPower = MaxPower;
    }
}

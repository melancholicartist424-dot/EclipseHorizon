using UnityEngine;

/// <summary>
/// Robust slope-aware Rigidbody controller with walking, sprinting,
/// jumping and natural sliding behaviour on steep surfaces. 
/// Updated for Unity 6 (uses linearVelocity).
/// </summary>
[RequireComponent(typeof(Rigidbody))]
public class SlopeAwareMovement : MonoBehaviour
{
    [Header("Movement Speeds")]
    public float walkSpeed = 4f;
    public float strafeSpeed = 3f;
    public float sprintMultiplier = 1.5f;
    public float airControl = 0.5f; // responsiveness while airborne (0–1)

    [Header("Jump Settings")]
    public float jumpForce = 6f;

    [Header("Slope Settings")]
    public float maxSlopeAngle = 45f;     // maximum climbable slope angle in degrees
    public float slideForce = 20f;        // force applied when sliding down steep slopes

    [Header("Ground Check")]
    public Transform groundCheck;         // origin of the ground sphere cast
    public float groundCheckRadius = 0.3f;
    public float groundCheckDistance = 0.5f;
    public LayerMask groundMask;

    private Rigidbody rb;
    private bool grounded;
    private Vector3 groundNormal = Vector3.up;

    private Vector2 moveInput;
    private bool sprinting;
    private bool jumpQueued;              // <-- fixed timing flag

    void Awake()
    {
        rb = GetComponent<Rigidbody>();
        rb.useGravity = true;
        rb.freezeRotation = true;
    }

    void Update()
    {
        // --- movement input ---
        moveInput = new Vector2(
            Input.GetAxisRaw("Horizontal"),
            Input.GetAxisRaw("Vertical")
        ).normalized;

        if (Input.GetButtonDown("Sprint"))
            sprinting = !sprinting;

        // --- jump input (just latch, don't clear here) ---
        if (Input.GetButtonDown("Jump"))
            jumpQueued = true; // will be consumed in FixedUpdate
    }

    void FixedUpdate()
    {
        CheckGround();
        HandleMovement();

        // consume the jump after physics step
        jumpQueued = false;
    }

    private void CheckGround()
    {
        grounded = false;
        groundNormal = Vector3.up;

        if (groundCheck == null)
            return;

        if (Physics.SphereCast(groundCheck.position, groundCheckRadius,
                Vector3.down, out RaycastHit hit, groundCheckDistance, groundMask))
        {
            float slopeAngle = Vector3.Angle(hit.normal, Vector3.up);
            groundNormal = hit.normal;

            if (slopeAngle <= maxSlopeAngle)
                grounded = true;
        }
    }

    private void HandleMovement()
    {
        Vector3 desiredMove =
            transform.forward * moveInput.y * walkSpeed +
            transform.right * moveInput.x * strafeSpeed;

        if (sprinting)
            desiredMove *= sprintMultiplier;

        Vector3 velocity = rb.linearVelocity;

        if (grounded)
        {
            if (velocity.y < 0f)
                velocity.y = 0f;

            // movement along ground
            Vector3 moveAlongGround = Vector3.ProjectOnPlane(desiredMove, groundNormal);
            velocity.x = moveAlongGround.x;
            velocity.z = moveAlongGround.z;

            // --- jump only when grounded ---
            if (jumpQueued)
            {
                velocity.y = jumpForce;
                grounded = false;
            }

            // slide on too-steep slopes
            float slopeAngle = Vector3.Angle(groundNormal, Vector3.up);
            if (slopeAngle > maxSlopeAngle)
            {
                Vector3 slopeDir = Vector3.Cross(Vector3.Cross(Vector3.up, groundNormal), groundNormal).normalized;
                rb.AddForce(slopeDir * slideForce, ForceMode.Acceleration);
            }
        }
        else
        {
            // air control
            velocity.x = Mathf.Lerp(rb.linearVelocity.x, desiredMove.x, airControl);
            velocity.z = Mathf.Lerp(rb.linearVelocity.z, desiredMove.z, airControl);
        }

        rb.linearVelocity = velocity;
    }

    void OnDrawGizmosSelected()
    {
        if (groundCheck == null) return;

        Gizmos.color = grounded ? Color.green : Color.red;
        Gizmos.DrawWireSphere(groundCheck.position, groundCheckRadius);
        Gizmos.DrawLine(groundCheck.position, groundCheck.position + Vector3.down * groundCheckDistance);
    }
}

/*
 * 
 * using UnityEngine;

public class Movement_1 : MonoBehaviour
{
    CharacterCore core;

    #region ground and jump
    [SerializeField]
    GameObject groundProbe;

    [SerializeField]
    float jumpSpeed;
    public float maxJumpTime;

    float jumpTimer = 0;
    [SerializeField]
    float jumpTimerStart;

    #endregion

    float sprintTime = 0;
    [SerializeField]
    float sprintTimeStart;
    [SerializeField]
    float sprintModifier;


    [SerializeField]
    float speed = 4f;
    [SerializeField]
    float strafeSpeed = 3f;

    Vector3 velocity;
    float currentY;


    #region Main Methods
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        core = GetComponent<CharacterCore>();

        jumpTimer = jumpTimerStart;
        velocity = new Vector3(0, 0, 0);
        //Cursor.lockState = CursorLockMode.Locked;
    }

    // Update is called once per frame
    void Update()
    {
        MovementController();
        Jump();
        /*
        Move();
        
SprintToggle();
        SprintTimer();
    }

    private void FixedUpdate()
    {
        //Debug.Log(movementMode);
        if (core._movementMode == CharacterCore.MovementMode.Ground || core._movementMode == CharacterCore.MovementMode.Fall)
        {
            core.Grounded = GroundCheck();
        }
    }

    #endregion

    void MovementController()
    {
        float forward;
        float strafe;

        if (core._movementMode != CharacterCore.MovementMode.Climb)
        {
            if (core.Rb.useGravity != true)
                core.Rb.useGravity = true;
            forward = Input.GetAxis("Vertical") * speed;
            strafe = Input.GetAxis("Horizontal") * strafeSpeed;
        }
        else
        {
            if (core.Rb.useGravity != false)
                core.Rb.useGravity = false;
            forward = Input.GetAxis("Vertical") * speed * .5f;
            strafe = Input.GetAxis("Horizontal") * strafeSpeed * .3f;
        }

        switch (core._movementMode)
        {

            case CharacterCore.MovementMode.Ground:

                if (!core.Grounded)
                {
                    core._movementMode = CharacterCore.MovementMode.Fall;
                }

                if (currentY != 0)
                    currentY = 0;

                velocity = Vector3.zero;
                if (!core.Sprinting)
                    velocity += transform.forward * Input.GetAxis("Vertical") * speed;
                else
                    velocity += transform.forward * Input.GetAxis("Vertical") * speed * sprintModifier;
                velocity += transform.right * Input.GetAxis("Horizontal") * strafeSpeed;
                velocity.y = 0;
                core.Rb.linearVelocity = velocity;

                break;



            case CharacterCore.MovementMode.Jump:
                YCalculation();
                if (Input.GetButton("Jump") == false || jumpTimer <= 0)
                {
                    core.Jumping = false;
                    jumpTimer = jumpTimerStart;
                    if (!core.Grounded)
                    {
                        core._movementMode = CharacterCore.MovementMode.Fall;
                    }
                    else
                        core._movementMode = CharacterCore.MovementMode.Ground;
                }
                else if (jumpTimer > 0)
                {
                    jumpTimer -= Time.deltaTime;
                }
                velocity = Vector3.zero;
                if (!core.Sprinting)
                    velocity += transform.forward * Input.GetAxis("Vertical") * speed;
                else
                    velocity += transform.forward * Input.GetAxis("Vertical") * speed * sprintModifier;
                velocity += transform.right * Input.GetAxis("Horizontal") * strafeSpeed;
                velocity.y = currentY;
                core.Rb.linearVelocity = velocity;
                break;

            case CharacterCore.MovementMode.Fall:
                if (core.Grounded)
                {
                    core._movementMode = CharacterCore.MovementMode.Ground;
                }
                else
                {
                    YCalculation();
                    velocity = Vector3.zero;
                    if (!core.Sprinting)
                        velocity += transform.forward * Input.GetAxis("Vertical") * speed;
                    else
                        velocity += transform.forward * Input.GetAxis("Vertical") * speed * sprintModifier;
                    velocity += transform.right * Input.GetAxis("Horizontal") * strafeSpeed;
                    velocity.y = currentY;
                }
                core.Rb.linearVelocity = velocity;
                //ADD CLIMBCHECK TO MOVE TO CLIMB
                break;

            case CharacterCore.MovementMode.Climb:
                break;

            case CharacterCore.MovementMode.Line:
                break;

        }

    }

    void Move()
    {
        if (core.Grounded && !core.Jumping)
        {
            velocity = new Vector3(0, 0, 0);
        }
        else if (!core.Jumping)
            velocity = new Vector3(0, -3, 0);

        velocity += transform.forward * Input.GetAxis("Vertical") * speed;
        velocity += transform.right * Input.GetAxis("Horizontal") * strafeSpeed;

        core.Rb.linearVelocity = velocity;
    }

    bool GroundCheck()
    {
        RaycastHit hit;
        if (Physics.Raycast(groundProbe.transform.position, Vector3.down, out hit, .3f, core.groundLayer))
        {
            Collider col = GetComponent<Collider>();
            Vector3 bottomPoint = col.ClosestPoint(hit.point - Vector3.up * 10f);
            float diff = bottomPoint.y - hit.point.y;
            transform.position -= new Vector3(0, diff, 0);
            //Debug.Log("grounded");
            return true;
        }
        else
        {
            //Debug.Log("not grounded");
            return false;
        }
    }

    void Jump()
    {
        if (Input.GetButtonDown("Jump") && core.Grounded && core._movementMode != CharacterCore.MovementMode.Jump)
        {
            core.Jumping = true;
            core._movementMode = CharacterCore.MovementMode.Jump;
        }
    }

    void SprintToggle()
    {
        if (Input.GetButtonDown("Sprint"))
        {
            if (!core.Sprinting)
                core.Sprinting = true;
        }
    }

    void SprintTimer()
    {
        if (core.Sprinting)
        {
            if (sprintTime > 0)
            {
                sprintTime -= Time.deltaTime;
            }
            else if (sprintTime <= 0)
            {
                sprintTime = sprintTimeStart;
                core.Sprinting = false;
            }

        }
    }

    void YCalculation()
    {
        if (core.Jumping)
        {
                currentY = jumpSpeed;
        }
        else
        {
            currentY -= 9.8f * Time.deltaTime;
        }
    }
}


*/

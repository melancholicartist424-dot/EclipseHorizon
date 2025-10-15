using UnityEngine;

public class Look : MonoBehaviour
{
    CharacterCore core;

    [Header("Look Settings")]
    [SerializeField] float mSensX = 2.2f;
    [SerializeField] float mSensY = 2.0f;
    [SerializeField] bool invertY = false;

    [Header("Pitch Limits")]
    [SerializeField] float minPitch = -75f;
    [SerializeField] float maxPitch = 75f;

    [Header("Optional Bone Reference")]
    [SerializeField] GameObject Bone;   // can be left null if unused

    float xRotation;   // yaw
    float yRotation;   // pitch

    void Start()
    {
        core = GetComponent<CharacterCore>();

        // Initialize to current transform orientation
        Vector3 rot = transform.localEulerAngles;
        xRotation = rot.y;
        yRotation = rot.x;

        // Lock cursor for mouse play
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void Update()
    {
        Looking();
    }

    void Looking()
    {
        // Combine mouse and controller right stick
        float mouseX = (Input.GetAxis("Mouse X") + Input.GetAxis("RightStickX")) * mSensX;
        float mouseY = (Input.GetAxis("Mouse Y") + Input.GetAxis("RightStickY")) * mSensY;

        if (invertY) mouseY = -mouseY;

        xRotation += mouseX;
        yRotation -= mouseY;
        yRotation = Mathf.Clamp(yRotation, minPitch, maxPitch);

        // Apply yaw to body
        transform.localRotation = Quaternion.Euler(0f, xRotation, 0f);

        // Apply pitch to camera
        if (core != null && core.PlayerCamera != null)
            core.PlayerCamera.transform.localRotation = Quaternion.Euler(yRotation, 0f, 0f);

        // Optional bone follow
        if (Bone != null)
            Bone.transform.localRotation = Quaternion.Euler(yRotation, 0f, 0f);
    }
}

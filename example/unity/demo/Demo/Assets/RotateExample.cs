using System.Collections;
using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class RotateExample : MonoBehaviour
{
    public float speed = 10f;
    public TextMeshProUGUI text;
    public Button button;
    public GameObject box;
    
    public Canvas gameCanvas;
    public Canvas menuCanvas;
    
    private static RotateExample instance;
    
    public static RotateExample Instance
    {
        get { return instance; }
    }
    
    void Awake()
    {
        // Singleton pattern implementation
        if (instance != null && instance != this)
        {
            Destroy(this.gameObject);
            return;
        }
        
        instance = this;
        
        // Persist across scene loads
        DontDestroyOnLoad(this.gameObject);
        
        // Subscribe to scene loaded event
        SceneManager.sceneLoaded += OnSceneLoaded;
    }
    
    void Start()
    {
        FindSceneReferences();
    }

    void Update()
    {
        this.UpdateSpeed();
    }
    
    private void OnDestroy()
    {
        instance = null;
        SceneManager.sceneLoaded -= OnSceneLoaded;
    }
    
    private void OnSceneLoaded(Scene scene, LoadSceneMode mode)
    {
        FindSceneReferences();
    }
    
    private void FindSceneReferences()
    {
        string currentScene = SceneManager.GetActiveScene().name;
        // Find references in GameScene
        if (text == null)
        {
            text = GameObject.Find("SpeedText")?.GetComponent<TextMeshProUGUI>();
        }
            
        if (box == null)
        {
            box = GameObject.Find("Box");
        }

        if (currentScene == "GameScene")
        {
            
            // Show elements
            if (gameCanvas != null) gameCanvas.gameObject.SetActive(true);
            if (menuCanvas != null) menuCanvas.gameObject.SetActive(false);
            if (text != null) text.gameObject.SetActive(true);
            if (box != null) box.SetActive(true);
            if (button != null) button.gameObject.SetActive(true);
        }
        else if (currentScene == "MenuScene")
        {
            // Hide elements in MenuScene
            if (gameCanvas != null) gameCanvas.gameObject.SetActive(false);
            if (menuCanvas != null) menuCanvas.gameObject.SetActive(true);
            if (text != null) text.gameObject.SetActive(false);
            if (box != null) box.SetActive(false);
            if (button != null) button.gameObject.SetActive(false);
        }
    }
    
    public void OpenMenuScene()
    {
        this.ChangeScene("MenuScene");
    }
    
    public void OpenGameScene()
    {
        this.ChangeScene("GameScene");
    }
    
    public void ChangeScene()
    {
        SceneManager.LoadScene(SceneManager.GetActiveScene().buildIndex + 1);
    }
    
    public void ChangeScene(string sceneName)
    {
        SceneManager.LoadScene(sceneName);
    }
    
    private void UpdateSpeed()
    {
        if (text != null && text.gameObject.activeInHierarchy)
        {
            text.text = $"Speed: {speed}";
        }
        
        if (box != null && box.activeInHierarchy)
        {
            box.transform.Rotate(Vector3.up, speed * Time.deltaTime);
            box.transform.Rotate(Vector3.right, speed * Time.deltaTime);
        }
    }
}
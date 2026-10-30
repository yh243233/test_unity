using System;
using System.IO;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;

namespace Harness.Editor
{
    public static class HarnessCommands
    {
        public const string ScenePath = "Assets/Harness/Scenes/HarnessDemo.unity";

        [MenuItem("Harness/Create Demo Scene If Missing")]
        public static void CreateSceneIfMissing()
        {
            if (File.Exists(ScenePath)) return;
            if (!Application.isBatchMode && !EditorSceneManager.SaveCurrentModifiedScenesIfUserWantsTo())
                throw new OperationCanceledException("Scene creation cancelled.");
            Directory.CreateDirectory("Assets/Harness/Scenes");
            var scene = EditorSceneManager.NewScene(NewSceneSetup.EmptyScene, NewSceneMode.Single);
            DemoWorld.Create();
            if (!EditorSceneManager.SaveScene(scene, ScenePath))
                throw new IOException("Could not save demo scene.");
            AssetDatabase.Refresh();
            Debug.Log("Created " + ScenePath);
        }

        // Unity invokes this only after successfully importing and compiling scripts.
        public static void Compile()
        {
            CreateSceneIfMissing();
            var args = Environment.GetCommandLineArgs();
            var index = Array.IndexOf(args, "-harnessMarker");
            if (index < 0 || index + 1 >= args.Length)
                throw new ArgumentException("-harnessMarker is required.");
            File.WriteAllText(args[index + 1], "compiled");
            Debug.Log("HARNESS_COMPILE_OK");
        }
    }
}

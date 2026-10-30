using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

namespace Harness.Tests
{
    public class PhysicsSmokeTests
    {
        [UnityTest]
        public IEnumerator BallFallsAndRestsOnFloor()
        {
            var root = DemoWorld.Create();
            try
            {
                var ball = root.transform.Find("PhysicsBall");
                // Fixed updates verify actual PhysicsModule simulation, not wall-clock timing.
                for (var i = 0; i < 150; i++) yield return new WaitForFixedUpdate();
                Assert.That(ball.position.y, Is.InRange(0.45f, 0.6f));
                Assert.That(ball.GetComponent<Rigidbody>().velocity.magnitude, Is.LessThan(0.2f));
            }
            finally { Object.Destroy(root); }
        }
    }
}

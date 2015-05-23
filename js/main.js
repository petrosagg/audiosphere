var timeStep=1/60;

// Initialize THREE.js
var scene = new THREE.Scene();
var camera = new THREE.PerspectiveCamera( 75, window.innerWidth / window.innerHeight, 1, 100 );
camera.position.z = 20;
scene.add( camera );

var light = new THREE.AmbientLight( 0x404040 ); // soft white light
scene.add( light );

var hemi = new THREE.HemisphereLight(0xFF8585, 0x000000, 0.5)
scene.add( hemi );

var renderer = new THREE.WebGLRenderer();
renderer.setSize( window.innerWidth, window.innerHeight );
document.body.appendChild( renderer.domElement );

// Initialise CANNON.js
var world = new CANNON.World();
world.gravity.set(0,0,0);
world.broadphase = new CANNON.NaiveBroadphase();
world.solver.iterations = 10;
// world.defaultContactMaterial.contactEquationStiffness = 5e6;
// world.defaultContactMaterial.contactEquationRelaxation = 10;

var SPHERE_COUNT = 20;
var spheres = [];
for (var i = 0; i < SPHERE_COUNT; i++) {
  spheres.push(createSphere(i*2 - SPHERE_COUNT, Math.random() * 0.01, 0, 0));
}

function createSphere(x, y, z, v) {
    var shape = new CANNON.Sphere(1);
    var body = new CANNON.Body({ mass: 1 });
    body.position.set(x, y, z);
    body.velocity.set(v, 0, 0);
    body.addShape(shape);
    world.addBody(body);

    var phase = Math.random() * Math.PI;
    var variance = Math.random() * 0.3

    body.preStep = function(){
      var origin = new CANNON.Vec3(x, y, z);
      origin.vsub(this.position, origin);
      var distance = origin.norm();
      origin.normalize();
      origin.mult(10 * distance, this.force);
      
      shape.radius = 1 + variance * (1 + Math.sin(Date.now() / 70 + phase));
      shape.updateBoundingSphereRadius();
      body.updateBoundingRadius();

      mesh.scale.set(shape.radius, shape.radius, shape.radius);
    }

    var geometry = new THREE.SphereGeometry( 1, 32, 32 );
    var material = new THREE.MeshPhongMaterial( { color: 0xE7112B, specular: 0xFF8585, shininess: 50, shading: THREE.SmoothShading } );
    var mesh = new THREE.Mesh( geometry, material );
    scene.add( mesh );

    return [ mesh, body ]
}

function animate() {
    requestAnimationFrame( animate );
    updatePhysics();
    renderer.render( scene, camera );
}
function updatePhysics() {
    // Step the physics world
    world.step(timeStep);
    // Copy coordinates from Cannon.js to Three.js
    for ( var i = 0; i < spheres.length; i++ ) {
      var mesh = spheres[i][0]
      var body = spheres[i][1]

      mesh.position.copy(body.position);
      mesh.quaternion.copy(body.quaternion);
    }
}

animate();

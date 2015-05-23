SPHERE_COUNT = 16
TIMESTEP = 1 / 60

# Initialize THREE.js
scene = new THREE.Scene()
camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 1, 100)
camera.position.z = 20
scene.add(camera)

# soft white light
light = new THREE.AmbientLight(0x404040)
scene.add(light)

hemi = new THREE.HemisphereLight(0xFF8585, 0x000000, 0.5)
scene.add(hemi)

renderer = new THREE.WebGLRenderer()
renderer.setSize(window.innerWidth, window.innerHeight)
document.body.appendChild(renderer.domElement)

# Initialise CANNON.js
world = new CANNON.World()
world.gravity.set(0,0,0)
world.broadphase = new CANNON.NaiveBroadphase()
world.solver.iterations = 10

createSphere = (x, y, z, i) ->
    shape = new CANNON.Sphere(1)
    body = new CANNON.Body({ mass: 1 })
    body.position.set(x, y, z)
    body.addShape(shape)
    world.addBody(body)

    phase = Math.random() * Math.PI
    variance = Math.random() * 0.3

    body.preStep = ->
      origin = new CANNON.Vec3(x, y, z)
      origin.vsub(this.position, origin)
      distance = origin.norm()
      origin.normalize()
      origin.mult(20 * distance, this.force)
      
      shape.radius = 0.3 + levelsData[i] * 4
      shape.updateBoundingSphereRadius()
      body.updateBoundingRadius()

      mesh.scale.set(shape.radius, shape.radius, shape.radius)

    geometry = new THREE.SphereGeometry(1, 32, 32)
    material = new THREE.MeshPhongMaterial({ color: 0xE7112B, specular: 0xFF8585, shininess: 50, shading: THREE.SmoothShading })
    mesh = new THREE.Mesh(geometry, material)
    scene.add(mesh)

    return [ mesh, body ]

spheres = (createSphere(i*2 - SPHERE_COUNT, Math.random() * 0.01, 0, i) for i in [0...SPHERE_COUNT])

animate = ->
    requestAnimationFrame(animate)
    updatePhysics()
    renderer.render(scene, camera)

updatePhysics = ->
    # Get audio data
    analyser.getByteFrequencyData(freqByteData) # <-- bar chart
    analyser.getByteTimeDomainData(timeByteData) # <-- waveform

    # normalize levelsData from freqByteData
    for i in [0...levelsCount]
      sum = 0
      for j in [0...levelBins]
        sum += freqByteData[(i * levelBins) + j]

      levelsData[i] = sum / levelBins/256; # freqData maxs at 256

      # adjust for the fact that lower levels are percieved more quietly
      # make lower levels smaller
      # levelsData[i] *=  1 + (i/levelsCount)/2;

    # Step the physics world
    world.step(TIMESTEP)
    # Copy coordinates from Cannon.js to Three.js
    for [mesh, body] in spheres
      mesh.position.copy(body.position)
      mesh.quaternion.copy(body.quaternion)

# Audio stuff
levelsCount = SPHERE_COUNT # should be factor of 512

audioContext = new window.AudioContext()
analyser = audioContext.createAnalyser()
analyser.smoothingTimeConstant = 0.8; # 0<->1. 0 is no time smoothing
analyser.fftSize = 1024
analyser.connect(audioContext.destination)
binCount = analyser.frequencyBinCount; # = 512
levelsData = []

levelBins = Math.floor(binCount / levelsCount) # number of bins in each level

freqByteData = new Uint8Array(binCount)
timeByteData = new Uint8Array(binCount)

length = 256
levelHistory = (0 for i in [0...256])

source = audioContext.createBufferSource()
source.connect(analyser)

# Load asynchronously
request = new XMLHttpRequest()
request.open("GET", "sample.mp3", true)
request.responseType = "arraybuffer"

request.onload = ->
  audioContext.decodeAudioData(request.response, (buffer) ->
    audioBuffer = buffer
    source.buffer = audioBuffer
    source.loop = true
    source.start(0.0)
  , (e) ->
    console.log(e)
  )

request.send()

animate()

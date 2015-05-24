TIMESTEP = 1 / 60
SPHERE_COUNT = 32
SPHERE_DIFFUSE = 0xE7112B
SPHERE_SPECULAR = 0xFF8585
SPHERE_SHININESS = 50
SPHERE_RADIUS = 0.7
SPHERE_MASS = 1
SPRING_STIFFNESS = 40
BACKGROUND_COLOR = 0x333333

# Initialize THREE.js
scene = new THREE.Scene()
camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 1, 100)
camera.position.z = 50
scene.add(camera)

# soft white light
light = new THREE.AmbientLight(0x404040)
scene.add(light)

hemi = new THREE.HemisphereLight(0xFF8585, 0x000000, 0.5)
scene.add(hemi)

renderer = new THREE.WebGLRenderer(alpha: true)
renderer.setSize(window.innerWidth, window.innerHeight)
renderer.setClearColor(BACKGROUND_COLOR, 0)
document.body.appendChild(renderer.domElement)

# Initialise CANNON.js
world = new CANNON.World()
world.gravity.set(0,0,0)
world.broadphase = new CANNON.NaiveBroadphase()
world.solver.iterations = 10

createSphere = (x, y, z, i) ->
    shape = new CANNON.Sphere(SPHERE_RADIUS)
    body = new CANNON.Body(mass: SPHERE_MASS)
    body.position.set(x, y, z)
    body.velocity.set(Math.random() * 5, Math.random() * 5, z)
    body.addShape(shape)
    world.addBody(body)

    body.preStep = ->
      origin = new CANNON.Vec3(x, y, z)
      origin.vsub(this.position, origin)
      distance = origin.norm()
      origin.normalize()
      origin.mult(SPRING_STIFFNESS * distance, this.force)
      
      shape.radius = 0.3 + Math.pow(levelsData[i], 1.2) * 5
      shape.updateBoundingSphereRadius()
      body.updateBoundingRadius()
      material.color = new THREE.Color(SPHERE_DIFFUSE)
      material.color.multiply(new THREE.Color(Math.min(0xffffff, 0xffffff * (levelsData[i] + 0.3))))
      material.specular = new THREE.Color(SPHERE_SPECULAR)
      material.specular.multiply(new THREE.Color(Math.min(0xffffff, 0xffffff * (levelsData[i] + 0.3))))

      mesh.scale.set(shape.radius, shape.radius, shape.radius)

    geometry = new THREE.SphereGeometry(SPHERE_RADIUS, 32, 32)

    material = new THREE.MeshPhongMaterial(
      color: SPHERE_DIFFUSE
      specular: SPHERE_SPECULAR
      shininess: SPHERE_SHININESS
      shading: THREE.SmoothShading
    )

    mesh = new THREE.Mesh(geometry, material)
    scene.add(mesh)

    return [ mesh, body ]

spheres = (createSphere((i*2 - SPHERE_COUNT) * 0.7, Math.random() * 0.01, Math.random(), i) for i in [0...SPHERE_COUNT])

animate = ->
    # Get audio data
    analyser.getByteFrequencyData(freqByteData) # <-- bar chart
    analyser.getByteTimeDomainData(timeByteData) # <-- waveform

    # normalize levelsData from freqByteData
    for i in [0...levelsCount]
      sum = 0
      for j in [0...levelBins]
        sum += freqByteData[(i * levelBins) + j]

      levelsData[i] = sum / levelBins / 256; # freqData maxs at 256

      # adjust for the fact that lower levels are percieved more quietly
      # make lower levels smaller
      levelsData[i] *=  1 + Math.pow((i/levelsCount) * 1.4, 2)

    # Step the physics world
    world.step(TIMESTEP)
    # Copy coordinates from Cannon.js to Three.js
    for [mesh, body] in spheres
      mesh.position.copy(body.position)
      mesh.quaternion.copy(body.quaternion)

    renderer.render(scene, camera)

    requestAnimationFrame(animate)

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

load = (id, callback) ->
  req = new XMLHttpRequest()
  req.onload = ->
    info = JSON.parse(req.responseText).info
    window.info = info

    audioStream = info.formats.filter((f) -> not f.height)[0] # Select audio only streams

    if audioStream
      audio = document.getElementById("audio")
      audio.crossOrigin = "anonymous"
      audio.src = "http://crossorigin.me/#{audioStream.url}"
      source = audioContext.createMediaElementSource(audio)
    else
      video = document.getElementById("video")
      video.crossOrigin = "anonymous"
      video.src = "http://crossorigin.me/#{info.url}"
      source = audioContext.createMediaElementSource(video)

    source.connect(analyser)

  req.open('GET', "https://youtube-dl.appspot.com/api/info?url=#{id}&flatten=false", true)
  req.send()

load(location.hash.substr(1))

animate()

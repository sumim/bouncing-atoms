"
This morph shows how an ideal gas simulation might work. When it gets step messages, it makes all its atom submorphs move along their velocity vectors, bouncing when they hit a wall. It also exercises the Morphic damage reporting and display architecture. Here are some things to try:

  1. Resize this morph as the atoms bounce around.
  2. In an inspector on this morph, evaluate ""self addAtoms: 10.""
  3. Try setting quickRedraw to false in invalidRect:. This gives the
     default damage reporting and incremental redraw. Try it for
     100 atoms.
  4. In the drawOn: method of AtomMorph, change drawAsRect to true.
  5. Create a HeaterCoolerMorph and embed it in the simulation. Extract
	it and use an inspector on it to evaluate ""self velocityDelta: -5"", then
     re-embed it. Note the effect on atoms passing over it.

"
Class {
	#name : #BouncingAtomsMorph,
	#superclass : #Morph,
	#instVars : [
		'damageReported',
		'infectionHistory',
		'transmitInfection',
		'recentTemperatures',
		'temperature'
	],
	#category : #'SqueakGitDemo-BouncingAtoms'
}

{ #category : #'parts bin' }
BouncingAtomsMorph class >> descriptionForPartsBin [
	^ self partName:	'BouncingAtoms' translatedNoop
		categories:		{'Just for Fun' translatedNoop}
		documentation:	'The original, intensively-optimized bouncing-atoms simulation by John Maloney' translatedNoop
]

{ #category : #'class initialization' }
BouncingAtomsMorph class >> initialize [

	self registerInFlapsRegistry.	
]

{ #category : #'class initialization' }
BouncingAtomsMorph class >> registerInFlapsRegistry [
	"Register the receiver in the system's flaps registry"
	self environment
		at: #Flaps
		ifPresent: [:cl | cl registerQuad: {#BouncingAtomsMorph, #new. 'Bouncing Atoms' translatedNoop. 'Atoms, mate' translatedNoop}
						forFlapNamed: 'Widgets']
]

{ #category : #'class initialization' }
BouncingAtomsMorph class >> unload [
	"Unload the receiver from global registries"

	self environment at: #Flaps ifPresent: [:cl |
	cl unregisterQuadsWithReceiver: self] 
]

{ #category : #other }
BouncingAtomsMorph >> addAtoms: n [
	"Add a bunch of new atoms."

	n timesRepeat: [
		| a |
		a := AtomMorph new.
		a randomPositionIn: bounds maxVelocity: 10.
		self addMorph: a].
	self stopStepping.

]

{ #category : #menu }
BouncingAtomsMorph >> addCustomMenuItems: aCustomMenu hand: aHandMorph [

	super addCustomMenuItems: aCustomMenu hand: aHandMorph.
	aCustomMenu add: 'start bouncing' translated action: #startStepping.
	aCustomMenu add: 'start infection' translated action: #startInfection.
	aCustomMenu add: 'set atom count' translated action: #setAtomCount.
	aCustomMenu add: 'show infection history' translated action: #showInfectionHistory:.

]

{ #category : #'submorphs-add\/remove' }
BouncingAtomsMorph >> addMorphFront: aMorph [
	"Called by the 'embed' meta action. We want non-atoms to go to the back."
	"Note: A user would not be expected to write this method. However, a sufficiently advanced user (e.g, an e-toy author) might do something equivalent by overridding the drag-n-drop messages when they are implemented."

	(aMorph isMemberOf: AtomMorph)
		ifTrue: [super addMorphFront: aMorph]
		ifFalse: [super addMorphBack: aMorph].
]

{ #category : #drawing }
BouncingAtomsMorph >> areasRemainingToFill: aRectangle [
	color isTranslucent
		ifTrue: [^ Array with: aRectangle]
		ifFalse: [^ aRectangle areasOutside: self bounds]
]

{ #category : #other }
BouncingAtomsMorph >> collisionPairs [
	"Return a list of pairs of colliding atoms, which are assumed to be
circles of known radius. This version uses the morph's positions--i.e.
the top-left of their bounds rectangles--rather than their centers."

	| count sortedAtoms radius twoRadii radiiSquared collisions p1 continue j p2 distSquared m1 m2 |
	count := submorphs size.
	sortedAtoms := submorphs 
				sorted: [:mt1 :mt2 | mt1 position x < mt2 position x].
	radius := 8.
	twoRadii := 2 * radius.
	radiiSquared := radius squared * 2.
	collisions := OrderedCollection new.
	1 to: count - 1
		do: 
			[:i | 
			m1 := sortedAtoms at: i.
			p1 := m1 position.
			continue := (j := i + 1) <= count.
			[continue] whileTrue: 
					[m2 := sortedAtoms at: j.
					p2 := m2 position.
					continue := p2 x - p1 x <= twoRadii  
								ifTrue: 
									[distSquared := (p1 x - p2 x) squared + (p1 y - p2 y) squared.
									distSquared < radiiSquared 
										ifTrue: [collisions add: (Array with: m1 with: m2)].
									(j := j + 1) <= count]
								ifFalse: [false]]].
	^collisions
]

{ #category : #initialization }
BouncingAtomsMorph >> defaultColor [
"answer the default color/fill style for the receiver"
	^ Color
		r: 0.8
		g: 1.0
		b: 0.8
]

{ #category : #drawing }
BouncingAtomsMorph >> drawOn: aCanvas [
	"Clear the damageReported flag when redrawn."

	super drawOn: aCanvas.
	damageReported := false.
]

{ #category : #initialization }
BouncingAtomsMorph >> initialize [
	"initialize the state of the receiver"
	super initialize.
	""
	damageReported := false.
	self extent: 400 @ 250.

	infectionHistory := OrderedCollection new.
	transmitInfection := false.
	self addAtoms: 30
]

{ #category : #initialization }
BouncingAtomsMorph >> intoWorld: newOwner [
"Make sure report damage at least once"
	damageReported := false.
	super intoWorld: newOwner.
	
]

{ #category : #'change reporting' }
BouncingAtomsMorph >> invalidRect: damageRect from: aMorph [
	"Try setting 'quickRedraw' to true. This invalidates the entire morph, whose bounds typically subsume all it's submorphs. (However, this code checks that assumption and passes through any damage reports for out-of-bounds submorphs. Note that atoms with super-high velocities do occaisionally shoot through the walls!) An additional optimization is to only submit only damage report per display cycle by using the damageReported flag, which is reset to false when the morph is drawn."

	| quickRedraw |
	quickRedraw := true.  "false gives the original invalidRect: behavior"
	(quickRedraw and:
	 [(bounds origin <= damageRect topLeft) and:
	 [damageRect bottomRight <= bounds corner]]) ifTrue: [
		"can use quick redraw if damage is within my bounds"
		damageReported ifFalse: [super invalidRect: bounds from: self].  "just report once"
		damageReported := true.
	] ifFalse: [super invalidRect: damageRect from: aMorph].  "ordinary damage report"
]

{ #category : #initialization }
BouncingAtomsMorph >> justDroppedInto: aWorld event: evt [

	damageReported := false.
	self changed
	
	
]

{ #category : #menu }
BouncingAtomsMorph >> setAtomCount [

	| countString count |
	countString := UIManager default
		request: 'Number of atoms?'
		initialAnswer: self submorphCount printString.
	countString isEmpty ifTrue: [^ self].
	count := Integer readFrom: (ReadStream on: countString).
	self removeAllMorphs.
	self addAtoms: count.

]

{ #category : #other }
BouncingAtomsMorph >> showInfectionHistory: evt [
	"Place a graph of the infection history in the world."

	| graph |
	infectionHistory isEmpty ifTrue: [^ self].
	graph := GraphMorph new data: infectionHistory.
	graph extent: ((infectionHistory size + (2 * graph borderWidth) + 5)@(infectionHistory last max: 50)).
	evt hand attachMorph: graph.

]

{ #category : #menu }
BouncingAtomsMorph >> startInfection [

	self submorphsDo: [:m | m infected: false].
	self firstSubmorph infected: true.
	infectionHistory := OrderedCollection new: 500.
	transmitInfection := true.
	self startStepping.

]

{ #category : #'stepping and presenter' }
BouncingAtomsMorph >> step [
	"Bounce those atoms!"

	| r bounces |
	super step.
	bounces := 0.
	r := bounds origin corner: (bounds corner - (8@8)).
	self submorphsDo: [ :m |
		(m isMemberOf: AtomMorph) ifTrue: [
			(m bounceIn: r) ifTrue: [bounces := bounces + 1]]].
	"compute a 'temperature' that is proportional to the number of bounces
	 divided by the circumference of the enclosing rectangle"
	self updateTemperature: (10000.0 * bounces) / (r width + r height).
	transmitInfection ifTrue: [self transmitInfection].

]

{ #category : #'stepping and presenter' }
BouncingAtomsMorph >> stepTime [
	"As fast as possible."

	^ 0

]

{ #category : #other }
BouncingAtomsMorph >> transmitInfection [

	| count |
	self collisionPairs do: [:pair | | infected |
		infected := false.
		pair do: [:atom | atom infected ifTrue: [infected := true]].
		infected
			ifTrue: [pair do: [:atom | atom infected: true]]].

	count := 0.
	self submorphsDo: [:m | m infected ifTrue: [count := count + 1]].
	infectionHistory addLast: count.
	count = submorphs size ifTrue: [
		transmitInfection := false.
		self stopStepping].

]

{ #category : #other }
BouncingAtomsMorph >> updateTemperature: currentTemperature [ 
	"Record the current temperature, which is taken to be the number of atoms that have bounced in the last cycle. To avoid too much jitter in the reading, the last several readings are averaged."

	recentTemperatures isNil 
		ifTrue: 
			[recentTemperatures := OrderedCollection new.
			20 timesRepeat: [recentTemperatures add: 0]].
	recentTemperatures removeLast.
	recentTemperatures addFirst: currentTemperature.
	temperature := recentTemperatures sum asFloat / recentTemperatures size
]

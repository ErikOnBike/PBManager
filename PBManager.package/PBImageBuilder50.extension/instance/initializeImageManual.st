*PBManager
initializeImageManual
	| process |

	self checkpoint: 'image_initialization'.
	
	self initializeSpecialObjectArray.
	
	self bootstrapInterpreter evaluateCode: '
	Smalltalk at: #Processor put: (ProcessorScheduler basicNew).
	(Smalltalk at: #Processor) instVarAt: 1 put: ((1 to: 80) collect: [ :i | ProcessList new ])'.

	"Initialize the processor association for the special objects array.
	Enchancement possible: This should be automatically managed by the createVMStubs method"
	objectSpace backend processorAssociation: (self bootstrapInterpreter evaluateCode: 'Smalltalk globals associationAt: #Processor.').
	
	process := objectSpace
		createProcessWithPriority: 40 
		doing: ('PharoBootstrapInitialization 
			initializeImageOfType: ''Pharo'' 
			major: {major} 
			minor: {minor} 
			patch: {patch}
			suffix: ''{suffix}'' 
			build: {build} 
			commitHash: ''{hash}''.' 
		format: {
			'major' -> versionInfo major.
			'minor' -> versionInfo minor.
			'patch' -> versionInfo patch.
			'suffix' -> versionInfo suffix.
			'build' -> versionInfo buildNumber.
			'hash' -> versionInfo commitHash.
	} asDictionary).
 	objectSpace installAsActiveProcess: process.
	
	self followForwardingPointers.

"	espellBackend simulator stackPages pages do: [ :page | espellBackend simulator stackPages freeStackPage: page ].
	espellBackend simulator freeUntracedStackPages."
	[[ espellBackend objectMemory flushNewSpace. ]
		on: Halt
		do: [:ex|
			"suppress halts from the usual suspects (development time halts)"	
			(#(#fullGC #compactImage  #doScavenge:) includes: ex signalerContext sender selector)
				ifTrue: [ex resume]
				ifFalse: [ex pass]]] on: AssertionFailure do: [ :e |
				((e signalerContext sender method selector == #assert:)
					and: [ e signalerContext sender sender method selector = #mapStackPages ])
						ifTrue: [ e resume ]
						ifFalse: [ e pass ]] .

	self freeForwarders.
	self compactImage.
	self reportSizes.

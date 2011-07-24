REBOL [
	Title:	 "Red/System Mach-O format emitter"
	Author:  "Nenad Rakocevic"
	File:	 %Mach-O.r
	Rights:  "Copyright (C) 2011 Nenad Rakocevic. All rights reserved."
	License: "BSD-3 - https://github.com/dockimbel/Red/blob/master/BSD-3-License.txt"
]

;; Reference doc: http://developer.apple.com/library/mac/#documentation/DeveloperTools/Conceptual/MachORuntime/Reference/reference.html

context [
	defs: compose [
		extensions [
			exe %""
			obj %.o
			lib %.a
			dll %.dylib
		]

		base-address	0
		page-size		4096		;-- target-dependent
		
		file-type [					;-- Constants for the filetype field of the mach_header
			object   		1     	; relocatable object file
			execute  		2     	; demand paged executable file
			fvmlib   		3		; fixed VM shared library file
			core     		4		; core file
			preload  		5		; preloaded executable file
			dylib    		6		; dynamically bound shared library
			dylinker 		7		; dynamic link editor
			bundle   		8		; dynamically bound bundle file
			dylib_stub  	9		; shared library stub for static
			dsym			10		; file that store symbol information for a corresponding binary file
		]
		flags [					 	;-- Constants for the flags field of the mach_header
			noundefs 		1     	; no undefined references
			incrlink 	 	2     	; output of an incremental link against a base file
			dyldlink 	 	4     	; input for the dynamic linker
			bindatload   	8    	; undefined references are bound by the dynamic linker when loaded
			prebound 	 	16      ; dynamic undefined references prebound
			split_segs   	32      ; read-only and read-write segments split
			lazy_init    	64      ; (obsolete) shared library init routine run lazily
			twolevel 	 	128     ; the image is using two-level name space bindings
			force_flat   	256     ; forcing all images to use flat name space bindings
			nomultidefs  	512     ; no multiple defintions of symbols in its sub-images
			nofixprebinding	1024    ; do not have dyld notify the prebinding agent about this executable
			prebindable  	2048    ; not prebound but can have its prebinding redone
			allmodsbound 	4096    ; binds to all two-level namespace modules of its dependent libraries
			subsections		8192	; sections of the object file can be divided into individual blocks
			canonical    	16384   ; canonicalized via the unprebind operation
			weakdefs        32768	; ?? (MH_WEAK_DEFINES)
			bindstoweak     65536	; ?? (MH_BINDS_TO_WEAK)
			allowstackexec  131072	; ?? (MH_ALLOW_STACK_EXECUTION)
			validflags      262143	; ?? 0003ffff (mask)
		]
		load-type [					;-- Constants for the cmd field of all load commands
			req_dyld 		-2147483648
			segment 		1 		; segment of this file to be mapped
			symtab   		2 		; link-edit stab symbol table info
			symseg   		3 		; link-edit gdb symbol table info (obsolete)
			thread   		4 		; thread
			unixthread   	5 		; unix thread (includes a stack)
			loadfvmlib   	6 		; load a specified fixed VM shared library
			idfvmlib 		7 		; fixed VM shared library identification
			ident    		8 		; (obsolete) object identification info 
			fvmfile  		9 		; (internal use) fixed VM file inclusion
			prepage      	10     	; (internal use) prepage command
			dysymtab 		11 		; dynamic link-edit symbol table info
			load_dylib   	12 		; load a dynamically linked shared library
			id_dylib 		13 		; dynamically linked shared lib ident
			load_dylinker 	14    	; load a dynamic linker
			id_dylinker  	15 		; dynamic linker identification
			prebound_dylib 	16  	; modules prebound for a dynamically linked shared library
			routines 		17    	; image routines
			sub_framework 	18   	; sub framework
			sub_umbrella 	19    	; sub umbrella
			sub_client   	20   	; sub client
			sub_library  	21    	; sub library
			twolevel_hints 	22  	; two-level namespace lookup hints
			prebind_cksum  	23  	; prebind checksum
			uuid			27
			load_weak_dylib -2147483624	; (0x18 | REQ_DYLD)
		]
		rights [
			none			0
			read			1
			write			2
			execute			4
		]
		sect-type [								 ;-- Constants for the type of a section
			regular       			 #{00000000} ; regular section
			zerofill     	 	 	 #{00000001} ; zero fill on demand section
			cstring_literals  		 #{00000002} ; section with only literal C strings
			_4byte_literals    		 #{00000003} ; section with only 4 byte literals
			_8byte_literals    		 #{00000004} ; section with only 8 byte literals
			literal_pointers  		 #{00000005} ; section with only pointers to
			non_lazy_symbol_pointers #{00000006} ; section with only non-lazy
			lazy_symbol_pointers     #{00000007} ; section with only lazy symbol
			symbol_stubs        	 #{00000008} ; section with only symbol
			mod_init_func_pointers   #{00000009} ; section with only function
			mod_term_func_pointers   #{0000000a} ; section with only function
			coalesced        		 #{0000000b} ; section contains symbols that
			section_attributes_usr   #{ff000000} ; User setable attributes
			attr_self_modifying_code #{04000000} ; section contains self-modifying code
			attr_pure_instructions 	 #{80000000} ; section contains only true
			attr_no_toc        	  	 #{40000000} ; section contains coalesced
			attr_strip_static_syms   #{20000000} ; ok to strip static symbols
			section_attributes_sys   #{00ffff00} ; system setable attributes
			attr_some_instructions   #{00000400} ; section contains some machine instructions
			attr_ext_reloc     		 #{00000200} ; section has external relocation entries
			attr_loc_reloc     		 #{00000100} ; section has local relocation entries
		]
		sym-type [
			n-stab					#{E0}		; stab entry
			n-pext					#{10}		; private extern bit
			n-type					#{0E}		; type of the symbol
			n-ext					#{01}		; external symbol
			;-- n-type flags --
			n-undf					#{00}		; undefined symbol
			n-abs					#{02}		; absolute symbol
			n-sect					#{0E}		; symbol defined in section n-sect
			n-pbud					#{0C}		; prebound valud for an undefined symbol
			n-indr					#{0A}		; alias symbol (n-value points to reference symbol)
		]
		sym-desc [
			undef-non-lazy			#{00}		; reference to an external non-lazy (data) symbol
			undef-lazy				#{01}		; external lazy symbol�that is, to a function call
			defined					#{02}		; symbol is defined in this module
			priv-def				#{03}		; defined in module, but private
			priv-def-non-lazy  		#{04}		; private, defined, non-lazy symbol
			priv-def-lazy  			#{05}		; private, defined, lazy symbol
			ref-dynamically			#{10}		; set for any defined symbol that is referenced by dynamic-loader APIs
			desc-discarded			#{20}		; do not set this bit in a fully linked image
			no-dead-strip			#{20}		; indicates to the static linker to never dead-strip the symbo
			weak-ref				#{40}		; symbol is a weak reference
			weak-def				#{80}		; symbol is a weak definition
		]
	]

	;; Mach-O Structures

	mach-header: make-struct [
		magic			[integer!]	;; 0xfeedface
		cpu-type		[integer!]	;; CPU_TYPE_I386 = 7
		cpu-sub-type	[integer!]	;; CPU_SUBTYPE_I386_ALL = 3
		file-type		[integer!]
		nb-cmds			[integer!]	;; number of load commands
		sz-cmds			[integer!]
		flags			[integer!]
	] none
		
	segment-command: make-struct [
		cmd				[integer!]	; load-type/segment
		size			[integer!]	; sizeof(segment_command + (sizeof(section) * segment->nsect))
		segname1		[decimal!]	; char segname[16]
		segname2		[decimal!]
		vmaddr			[integer!]	; starting virtual memory address of this segment
		vmsize			[integer!]	; number of bytes of virtual memory occupied by this segment
		fileoff			[integer!]	; offset in this file of the data to be mapped at vmaddr
		filesize		[integer!]	; number of bytes occupied by this segment on disk
		maxprot			[integer!]	; maximum permitted virtual memory protections of this segment
		initprot		[integer!]	; initial virtual memory protections of this segment
		nsects			[integer!]  ; number of section data structures following this load command
		flags			[integer!]	;
	] none
	
	unix-thread-cmd: make-struct [
		cmd				[integer!]	; load-type/segment
		size			[integer!]	; sizeof(segment_command + (sizeof(section) * segment->nsect))
		flavor			[integer!]	; x86_THREAD_STATE32 = 1
		count			[integer!]	; nb of thread state 32-bit entries (16)
		eax				[integer!]
		ebx				[integer!]
		ecx				[integer!]
		edx				[integer!]
		edi				[integer!]
		esi				[integer!]
		ebp				[integer!]
		esp				[integer!]
		ss				[integer!]
		eflags			[integer!]
		eip				[integer!]
		cs				[integer!]
		ds				[integer!]
		es				[integer!]
		fs				[integer!]
		gs				[integer!]
	] none
	
	load-dylib-cmd: make-struct [
		cmd				[integer!]	; load-type/segment
		size			[integer!]	; sizeof(segment_command + (sizeof(section) * segment->nsect))
		offset			[integer!]	; = 24 (from the start of the load cmd)
		timestamp		[integer!]	; date and time when the shared library was built
		version			[integer!]	; current version of the shared library
		compat			[integer!]	; compatibility version of the shared library
	] none
	
	dylinker-cmd: make-struct [
		cmd				[integer!]	; load-type/segment
		size			[integer!]	; sizeof(segment_command + (sizeof(section) * segment->nsect))
		offset			[integer!]	; = 12 (from the start of the load cmd)
	] none
	
	section-header: make-struct [
		sectname1		[decimal!]	; char sectname[16]
		sectname2		[decimal!]
		segname1		[decimal!]	; char segname[16]
		segname2		[decimal!]
		addr			[integer!]	; virtual memory address of this section
		size			[integer!]	; size in bytes of the virtual memory occupied by this section
		offset			[integer!]	; offset to this section in the file
		align			[integer!]	; section�s byte alignment as power of two
		reloff			[integer!]	; file offset of the first relocation entry for this section.
		nreloc			[integer!]	; number of relocation entries located at reloff for this section.
		flags			[integer!]
		reserved1		[integer!]
		reserved2		[integer!]
	] none
	
	symtab-cmd: make-struct [
		cmd				[integer!]	; load-type/segment
		size			[integer!]	; sizeof(segment_command + (sizeof(section) * segment->nsect))
		symoff			[integer!]	; symbol table file offset (from head of file)
		nsyms			[integer!]	; nb of symbol entries
		stroff			[integer!]	; string table file offset (from head of file)
		strsize			[integer!]	; size of string table in bytes
	] none
	
	dysymtab-cmd: make-struct [
		cmd				[integer!]	; load-type/segment
		size			[integer!]	; sizeof(segment_command + (sizeof(section) * segment->nsect))
		ilocalsym		[integer!]	; index of the first symbol in the group of local symbols
		nlocalsym		[integer!]	; total number of symbols in the group of local symbols
		iextdefsym		[integer!]	; index of the first symbol in the group of defined external symbols
		nextdefsym		[integer!]	; total number of symbols in the group of defined external symbols
		iundefsym		[integer!]	; index of the first symbol in the group of undefined external symbols
		nundefsym		[integer!]	; total number of symbols in the group of undefined external symbols
		tocoff			[integer!]	; byte offset from the start of the file to the table of contents data
		ntoc			[integer!]	; number of entries in the table of contents
		modtaboff		[integer!]	; byte offset from the start of the file to the module table data
		nmodtab			[integer!]	; number of entries in the module table
		extrefsymoff	[integer!]	; byte offset from the start of the file to the external reference table data
		nextrefsyms		[integer!]	; number of entries in the external reference table
		indirectsymoff	[integer!]	; byte offset from the start of the file to the indirect symbol table data
		nindirectsyms	[integer!]	; number of entries in the indirect symbol table
		extreloff		[integer!]	; byte offset from the start of the file to the external relocation table data
		nextrel			[integer!]	; number of entries in the external relocation table
		locreloff		[integer!]	; byte offset from the start of the file to the local relocation table data
		nlocrel			[integer!]	; number of entries in the local relocation table
	] none
	
	nlist: make-struct [
		n-strx			[integer!]	; index in the string table
		n-type			[char!]		; bit flags
		n-sect			[char!]		; NO-SECT (if external) or section index (one-based)
		n-desc			[short]		; nature of symbol (for non-stab symbols)
		n-value			[integer!]	; symbol type specific value
	] none
	
	pointer: make-struct [
		value [integer!]			;-- 32/64-bit, watch out for endianess!!
	] none

	;-- Globals --
	
	segments: [
	;-- class ------ name ------ mem --- file - rights - payload - memalign
	;						   - off sz  off sz	-
	  segment		__PAGEZERO   0	page 0 	 0	[]		  - 	   page []
	  segment 		__TEXT	 	 ?	 ? 	 ?	 ?	[r x]	  -		   page [
		section		__text	 	 ?	 ?	 ?	 ?	 -		  code	   word
	  ]
	  segment 		__DATA	 	 ?	 ?	 ?	 ?	[r w]	  -		   page [
		section		__data	 	 ?	 ?	 ?	 ?	 -		  data	   word
	  ]
	  uthread		-			 -	 -   -	 -   - 		  -		   -	[]
	]
	
	imports-refs:		make block! 10		;-- [ptr [refs] ...]
	dylink?:			no					;-- yes => dynamic library linking required
	segment-sz:			length? form-struct segment-command
	section-sz:			length? form-struct section-header
	load-cmds-nb:		0
	load-cmds-sz:		0
	stub-size:			5					;-- imported functions slot size

	;-- Mach-O structure builders --
	
	to-c-string: func [value][join value null]
	
	pad4: func [s [string!] /local rem][
		unless zero? rem: (length? s) // 4 [
			insert/dup tail s #"^@" 4 - rem
		]
		s
	]
	
	get-ceiling: func [type [word!]][
		switch/default type [
			page [defs/page-size]
			word [4]						;-- 4 => 32-bit, 8 => 64-bit @@
			byte [1]
		][4]								;-- 4 => 32-bit, 8 => 64-bit @@								
	]
	
	sections?: func [list [block!]][(length? list) / 9]
	
	get-struct-size: func [type [word!]][
		switch type [
			segment  [segment-sz]
			uthread  [length? form-struct unix-thread-cmd]
			dylinker [length? form-struct dylinker-cmd]
			lddylib  [length? form-struct load-dylib-cmd]
			symtab	 [length? form-struct symtab-cmd]
			dysymtab [length? form-struct dysymtab-cmd]
		]
	]
	
	get-rights?: func [spec [block!] /local flags][
		flags: 0
		foreach flag spec [
			flags: flags + defs/rights/(select [r read w write x execute] flag)
		]
		flags
	]
	
	get-flags: func [type [word!] /local flags][
		flags: defs/sect-type
		to integer! switch/default type [
			code [
				flags/attr_pure_instructions
					or flags/attr_some_instructions
			]
			jmptbl [
				flags/attr_pure_instructions
					or flags/attr_some_instructions
					or flags/attr_self_modifying_code
					or flags/symbol_stubs
			]
		][flags/regular]
	]
	
	get-section-addr: func [name [word!] /local addr][
		parse segments [some [into [thru name set addr skip | none] | skip]]	
		addr
	]
	
	get-segment-info: func [name [word!] /local addr][
		next find segments name
	]
		
	prepare-headers: func [
		job [object!]
		/local seg sec addr fpos get-value size sz header-sz hd-sz
	][
		get-value: func [n value][
			switch/default seg/:n [? [value] page [defs/page-size]][seg/:n]
		]
		
		load-cmds-sz: 0
		seg: segments
		until [
			load-cmds-sz: load-cmds-sz + get-struct-size seg/1
			if string? seg/2 [load-cmds-sz: load-cmds-sz + length? seg/2]	;-- account for load-dylib path
			load-cmds-nb: load-cmds-nb + 1
			unless empty? seg/10 [
				load-cmds-sz: load-cmds-sz + (section-sz * sections? seg/10)
			]
			tail? seg: skip seg 10
		]
		
		header-sz: load-cmds-sz + length? form-struct mach-header
		addr: 0
		fpos: header-sz
		
		seg: segments
		until [
			if seg/1 = 'segment [
				seg/3: addr: round/ceiling/to get-value 3 addr get-ceiling seg/9 ;-- offset in memory (segment)
				seg/5: fpos: round/ceiling/to get-value 5 fpos get-ceiling seg/9 ;-- offset in file (segment)

				sec: seg/10
				hd-sz: either seg/2 = '__TEXT [header-sz][0]	;-- account for headers
				size: either seg/8 = '- [0][length? job/sections/(seg/8)/2]
				while [not tail? sec][
					sz: length? job/sections/(sec/8)/2					
					sec/3: addr: round/ceiling/to addr + hd-sz get-ceiling sec/9 ;-- offset in memory (section)
					sec/4: sz							;-- size in memory (section)
					sec/5: fpos: round/ceiling/to fpos + hd-sz get-ceiling sec/9 ;-- offset in file (section)
					sec/6: sz							;-- size in file (section)
					size:  size + sz + hd-sz
					addr:  addr + sz
					fpos:  fpos + sz
					sec: skip sec 9
				]
				size: round/ceiling/to size defs/page-size
				seg/4: get-value 4 size 				;-- size in memory (segment)
				seg/6: get-value 6 size					;-- size in file (segment)
				if zero? size [
					addr:  addr + seg/4
					fpos:  fpos + seg/6
				]
			]
			tail? seg: skip seg 10
		]
	]
	
	emit-page-aligned: func [buf [binary!] data [binary!] /local page rem][
		append buf data
		unless zero? rem: (length? buf) // page: defs/page-size [
			insert/dup tail buf null page - rem
		]
	]
	
	resolve-data-refs: func [job [object!] /local cbuf dbuf data code][
		cbuf: job/sections/code/2
		dbuf: job/sections/data/2
		forskip segments 10 [
			switch segments/2 [
				__TEXT [code: get-section-addr '__text]
				__DATA [data: segments/3]
			]
		]
		linker/resolve-symbol-refs job cbuf dbuf code data pointer
	]
	
	resolve-import-refs: func [job [object!] /local code base][
		code: job/sections/code/2
		base: get-section-addr '__jump_table

		foreach [ptr reloc] imports-refs [
			pointer/value: ptr: base + ptr
			foreach ref reloc [
				change at code ref form-struct pointer 	;TBD: check endianness + x-compilation
			]
		]
	]

	build-imports: func [
		job [object!]
		/local sym-tbl dy-sym-tbl lib cnt entry
	][
		sym-tbl:    make binary! 1024
		dy-sym-tbl: make binary! 1024
		str-tbl: 	make binary! 1024
		append str-tbl #{00000000}					;-- start with 4 null bytes @@
		
		insert find segments 'uthread [
			segment			__IMPORT	 ?	 ? 	 ?	 ?	[r w x]	  -   	   page [
				section		__jump_table ?	 ?   ?   ?  -		  jmptbl   byte
			]
			segment			__LINKEDIT	 ?	 ?	 ?	 ?  [r]		  symbols  page [] 
			dylinker		-			 -	 -   -	 -   - 		  -		   -	[]
			symtab			-			 -	 -   -	 -   - 		  -		   -	[]
			dysymtab		-			 -	 -   -	 -   - 		  -		   -	[]
			;twolvlhints	-			 -	 -   -	 -   - 		  -		   -	[]
		]
		segments/dylinker: pad4 to-c-string "/usr/lib/dyld"
		
		lib: 1										;-- one-based index
		cnt: 0
		foreach [name list] job/sections/import/3 [
			name: to-c-string name
			if name/1 <> slash [insert name "/usr/lib/"]
			insert find segments 'symtab compose [
				  lddylib (pad4 name) -	 -   -	 -   - 		  -		   -	[]
			]
			foreach [def reloc] list [		
				entry: make-struct nlist none
				entry/n-strx:  length? str-tbl
				entry/n-type:  to integer! defs/sym-type/n-undf or defs/sym-type/n-ext
				entry/n-sect:  0					;-- NO_SECT
				entry/n-desc:  (to integer! defs/sym-desc/undef-lazy) or shift/left lib 8
				entry/n-value: 0
				append sym-tbl form-struct entry
				
				pointer/value: cnt
				append dy-sym-tbl form-struct pointer
				
				repend imports-refs [cnt * stub-size reloc]		;-- store symbol jump table offset
				
				append str-tbl join "_" to-c-string def
				cnt: cnt + 1
			]
			lib: lib + 1
		]
		repend job/sections [
			'jmptbl reduce [
				'- head insert/dup make binary! cnt * stub-size #{F4F4F4F4F4} cnt
			]
			'symbols reduce [
				reduce [cnt length? sym-tbl length? dy-sym-tbl length? str-tbl]
				rejoin [sym-tbl dy-sym-tbl str-tbl]
			]
		]
	]
	
	build-dysymtab-command: func [job [object!] spec [block!] /local sc sym-info][
		sym-info: job/sections/symbols/1

		sc: make-struct dysymtab-cmd none
		sc/cmd:			   defs/load-type/dysymtab
		sc/size:		   get-struct-size 'dysymtab
		sc/ilocalsym:	   0
		sc/nlocalsym:	   0
		sc/iextdefsym:	   0
		sc/nextdefsym:	   0
		sc/iundefsym:	   0
		sc/nundefsym:	   sym-info/1
		sc/tocoff:		   0
		sc/ntoc:		   0
		sc/modtaboff:	   0
		sc/nmodtab:		   0
		sc/extrefsymoff:   0
		sc/nextrefsyms:	   0
		sc/indirectsymoff: (third get-segment-info '__LINKEDIT) + sym-info/2
		sc/nindirectsyms:  sym-info/1
		sc/extreloff:	   0
		sc/nextrel:		   0
		sc/locreloff:	   0
		sc/nlocrel:		   0
		sc: form-struct sc
		sc
	]
	
	build-symtab-command: func [job [object!] spec [block!] /local sc sym-info][
		sym-info: job/sections/symbols/1
		
		sc: make-struct symtab-cmd none
		sc/cmd:			defs/load-type/symtab
		sc/size:		get-struct-size 'symtab
		sc/symoff:		third get-segment-info '__LINKEDIT
		sc/nsyms:		sym-info/1
		sc/stroff:		sc/symoff + sym-info/2 + sym-info/3
		sc/strsize:		sym-info/4
		sc: form-struct sc
		sc
	]
	
	build-lddylib-command: func [job [object!] spec [block!] /local lc][
		lc: make-struct load-dylib-cmd none
		lc/cmd:			defs/load-type/load_dylib
		lc/size:		(get-struct-size 'lddylib) + length? spec/2
		lc/offset:		24
		lc/timestamp:	2
		lc/version:		to integer! #{007D0000}
		lc/compat:		to integer! #{00010000}
		lc: form-struct lc
		append lc spec/2
		lc
	]
	
	build-dylinker-command: func [job [object!] spec [block!] /local dl][
		dl: make-struct dylinker-cmd none
		dl/cmd:			defs/load-type/load_dylinker
		dl/size:		(get-struct-size 'dylinker) + length? spec/2
		dl/offset:		12
		dl: form-struct dl
		append dl spec/2	
		dl
	]
	
	build-uthread-command: func [job [object!] spec [block!] /local ut][
		ut: make-struct unix-thread-cmd none
		ut/cmd:			defs/load-type/unixthread
		ut/size:		get-struct-size 'uthread
		ut/flavor:		1							;-- x86_THREAD_STATE32
		ut/count:		16
		ut/eip:			get-section-addr '__text
		form-struct ut
	]
	
	build-section-header: func [spec [block!] seg-name [word!] /local sh][
		sh: make-struct section-header none
		sh/addr:		spec/3
		sh/size:		spec/6
		sh/offset:		spec/5
		sh/align:		to integer! log-2 select [byte 1 word 4 dword 8] spec/9	;-- 32/64-bit @@
		sh/reloff:		0
		sh/nreloc:		0
		sh/flags:		get-flags spec/8
		sh/reserved1:	0
		sh/reserved2:	either spec/2 = '__jump_table [stub-size][0]
		sh: form-struct sh
		change sh to-c-string spec/2
		change at sh 17 to-c-string seg-name
		sh
	]
	
	build-segment-command: func [job [object!] spec [block!] /local sc][
		sc: make-struct segment-command none
		sc/cmd:			defs/load-type/segment
		sc/size:		segment-sz + (section-sz * sections? spec/10)
		sc/vmaddr:		spec/3
		sc/vmsize:		spec/4
		sc/fileoff:		spec/5
		sc/filesize:	spec/6
		sc/maxprot:		either empty? spec/7 [0][get-rights? [r w x]]
		sc/initprot:	get-rights? spec/7
		sc/nsects:		sections? spec/10
		sc/flags:		4						;-- SG_NORELOC
		sc: form-struct sc
		change at sc 9 to-c-string spec/2
		sc
	]
		
	build-mach-header: func [job [object!] /local mh][
		mh: make-struct mach-header none
		mh/magic:			to integer! #{FEEDFACE}
		mh/cpu-type:		7					;-- CPU_TYPE_I386
		mh/cpu-sub-type:	3					;-- CPU_SUBTYPE_I386_ALL
		mh/file-type:		defs/file-type/execute
		mh/nb-cmds:			load-cmds-nb
		mh/sz-cmds:			load-cmds-sz
		mh/flags:			defs/flags/noundefs
		if dylink? [
			mh/flags: mh/flags 
				or defs/flags/dyldlink
				or defs/flags/subsections
				;or defs/flags/bindatload
		]
		form-struct mh
	]

	build: func [
		job [object!]
		/local
			base-address dynamic-linker out sections

	] [
		base-address: any [job/base-address defs/base-address]
		dynamic-linker: any [job/dynamic-linker ""]
		
		dylink?: not empty? job/sections/import/3
		
		clear imports-refs
		if dylink? [build-imports job]
		
		prepare-headers job
		
		out: job/buffer
		append out build-mach-header job
		seg: segments
		forskip seg 10 [
			append out switch seg/1 [
				segment  [build-segment-command  job seg]
				uthread  [build-uthread-command  job seg]
				dylinker [build-dylinker-command job seg]
				lddylib  [build-lddylib-command  job seg]
				symtab	 [build-symtab-command 	 job seg]
				dysymtab [build-dysymtab-command job seg]
			]
			unless empty? sections: seg/10 [
				forskip sections 9 [
					append out build-section-header sections seg/2
				]
			]
		]
		
		if dylink? [resolve-import-refs job]
		resolve-data-refs job
		
		emit-page-aligned out job/sections/code/2
		emit-page-aligned out job/sections/data/2
	
		if dylink? [
			emit-page-aligned out job/sections/jmptbl/2
			emit-page-aligned out job/sections/symbols/2
		]
	]
]
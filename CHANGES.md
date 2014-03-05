2014-01-29 v0.7.1.3
	* Make sure the refactored file retains its original extension, so
	that syntax highlighting still works while the preview is being done.
2014-01-28 v0.7.1.2
	* Ensure that the right target is activated for the primary file
	when it belongs to a non-library target,not just for client
	modules of it.
2014-01-27 v0.7.1.1
	* The non-library targets were having the wrong path prepended
2014-01-26 v0.7.1.0
	* Rework the module loading to load each target in turn, so that
	all exe, test, benchmark etc will be refactored in one go
2013-12-18 v0.7.0.9
	* Tweaks to output stage based on real world use. Renaming seems
	stable, liftXXX, demote have issues
	* Removed deprecated hspec-discover dependency
	* added ghc-hare show command to the elisp as well to be able to
	check that it is using the correct cabal file
2013-12-16 v0.7.0.8
	* Major rewrite of the token output stage. It now makes use of a
	dual-tree structure to manage the maintenance of required vertical
	layout while refactoring.
2013-10-21 v0.7.0.7
	* Bump the lower bound on Diff
2013-10-01 v0.7.0.6
	* Sort out most of the do/in/let layout when renaming. Only nested
	layout changes to be dealt with.
	* Updated to use the latest ghc-mod, with cabal 1.18.x sandbox
	support.
	* Updated to latest versions of Diff and hspec
	* When refactoring a CPP pre-processed file, read the preprocessor
	directives and non-compiled code as comments, so the source can be
	round-tripped. This allows refactoring of simple #if/#else/#endif
	code. NOTE: no refactoring is done on code that is not live after
	the preprocessor.
2013-09-12  v0.7.0.5
	* Now able to get tokens for a file pre-processed with CPP. But it
	is the pre-processed output, so the CPP directives are stripped
	out when writing out the refactored source.
	
2013-09-11  v0.7.0.4
	* Correct Haddock compile error. Close #4
	* hsWithBndrs only exists for GHC > 7.4.x
2013-09-10  v0.7.0.3
	
	* Fix elisp, would not commit refactoring due to missing methods
	
2013-09-08  v0.7.0.2

	* Fix issue #3: ifToCase formatting
	
2013-09-05  v0.7.0.1

	* Fix issue #2: elisp

2013-09-04 v0.7.0.0

	* Alpha release with new GHC API


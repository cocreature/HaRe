;; hare.el --- Top level of HaRe package, loads all subparts

;; Note: based on
;; https://github.com/RefactoringTools/wrangler/blob/master/elisp/wrangler.el.src

;; Prerequisites

;; (require 'vc-hooks)
;; (require 'wrangler-clearcase-hooks)
;; (require 'vc)
;; (require 'erlang)
;; (require 'distel)
;; (require 'read-char-spec)

(if (eq (substring emacs-version 0 4) "22.2")
    (require 'ediff-init1)
  (require 'ediff-init))

(provide 'hare)

(defgroup hare nil
  "HaRe options.")

(defcustom hare-search-paths (cons (expand-file-name ".") nil )
        "List of directories to search for .hs and .lhs files to refactor."
        :type '(repeat directory)
        :group 'hare)

(defcustom ghc-hare-command "ghc-hare"
     "The command name of \"ghc-hare\""
     :type 'string
     :group 'hare)

;; (defcustom version-control-system 'none
;;   "* FOR CASESTUDY USE ONLY.* Version control system used for storing casestudy results."
;;   :type '(choice
;;        (const none)
;;        (const ClearCase)
;;        (const Git)
;;        (const SVN))
;;   :group 'wrangler)

;; (defcustom dirs-to-monitor nil
;;   "*FOR CASESTUDY USE ONLY.* List of directories to be monitored by Wrangler to log refactoring activities."
;;   :type '(repeat directory)
;;   :group 'wrangler)


;; (defcustom refactor-log-file ""
;;   "*FOR CASESTUDY WITH ClearCase ONLY.* Path and name of the refactoring log file."
;;   :type '(file :must-match t)
;;   :group 'wrangler)


;; (defcustom refac-monitor-repository-path ""
;;   "*FOR CASESTUDY WITH Git/SVN ONLY.* Path to the Wrangler monitor reposiotry"
;;   :type 'directory
;;   :group 'wrangler)

;; (defcustom log-source-code nil
;;   "*FOR CASESTUDY USE ONLY* 'off' means to log the refactoring commands; 'on' means
;;   to log both refactoring commands and source code."
;;   :type 'boolean
;;   :group 'wrangler)

(defun hare-customize ()
  "Customization of group `hare' for the Haskell Refactorer."
  (interactive)
  (customize-group 'hare))

;; (require 'erl)
;; (require 'erl-service)

;; Compatibility with XEmacs
(unless (fboundp 'define-minor-mode)
  (defalias 'define-minor-mode 'easy-mmode-define-minor-mode))

(setq kill-buffer-query-functions
      (remove 'process-kill-buffer-query-function
              kill-buffer-query-functions))


(defvar modified-files nil)
(defvar files-to-write nil)
(defvar files-to-rename nil)
(defvar refactoring-committed nil)
(defvar unopened-files nil)
(defvar ediff-ignore-similar-regions t)
(defvar refactor-mode nil)
(defvar has-warning 'false)
(defvar refac-result nil)
;; (defvar my_gen_refac_menu_items nil)
;; (defvar my_gen_composite_refac_menu_items nil)
;; (defvar hare_ext (expand-file-name (concat (getenv "HOME") "/.hare/elisp/hare_ext.el")))

;; (setq modified-files nil)
;; (setq files-to-write nil)
;; (setq files-to-rename nil)
;; (setq refactoring-committed nil)
;; (setq unopened-files nil)
;; (setq ediff-ignore-similar-regions t)
;; (setq refactor-mode nil)
;; (setq has-warning 'false)
;; (setq refac-result nil)
;; (setq my_gen_refac_menu_items nil)
;; (setq my_gen_composite_refac_menu_items nil)
;; (setq hare_ext (expand-file-name (concat (getenv "HOME") "/.hare/elisp/hare_ext.el")))


(defun hare-ediff(file1 file2)
  "run ediff on file1 and file2"
  (setq refactor-mode t)
  (ediff file1 file2)
)
(defun my-ediff-qh()
  "Function to be called when ediff quits."
  (if (equal refactor-mode t)
      (if (equal modified-files nil)
          (commit-or-abort)
        (if (y-or-n-p "Do you want to preview changes made to other files?")
            (progn
              (defvar file-to-diff)
              (setq file-to-diff (car modified-files))
              (setq modified-files (cdr modified-files))
              (if (get-file-buffer-1 file-to-diff)
                  nil
                (setq unopened-files (cons file-to-diff unopened-files))
                )
              (hare-ediff file-to-diff (concat (file-name-sans-extension file-to-diff) 
                                                   (file-name-extension file-to-diff t) ".refactored")))
          (progn
            (setq modified-files nil)
            (commit-or-abort))))
    nil))


;; (defun is-a-monitored-file(file)
;;   "check if a file is monitored by Hare for refactoring activities."
;;   (setq monitored nil)
;;   (setq dirs dirs-to-monitor)
;;   (setq file1 (if (featurep 'xemacs)
;;                (replace-in-string file "/" "\\\\")
;;              file))
;;   (while (and (not monitored) (not (equal dirs nil)))
;;     (if (string-match (regexp-quote (file-name-as-directory (car dirs))) file1)
;;      (setq monitored 'true)
;;       (setq dirs (cdr dirs))
;;       ))
;;   (if monitored
;;       (car dirs)
;;     nil))

(defun log-search-result(curfilename logmsg)
  (let ((dir (is-a-monitored-file curfilename)))
    (if (equal nil dir)
        nil
      (cond
       ((equal version-control-system 'ClearCase)
        (add-logmsg-to-logfile-clearcase logmsg))
       ((or (equal version-control-system 'Git)
            (equal version-control-system 'SVN))
        (write-to-refac-logfile dir logmsg "Clone Detection"))
       (t nil)
       ))))

(defun add-logmsg-to-logfile-clearcase(logmsg)
  "Add logmsg to the refactor log file which is stored in a clearase repository." 
  (run-hook-with-args 'before-commit-functions (list refactor-log-file) nil)
  (run-hook-with-args 'after-commit-functions refactor-log-file logmsg)
)

(defun prepare-to-commit()
  ";make sure the files are writeable when cleaecase is used as the repository."
  (run-hook-with-args 'before-commit-functions files-to-write files-to-rename)
  (setq files-to-write nil)
  (setq files-to-rename nil)
  )

(defun commit()
  "commit the refactoring result."
  (if (equal version-control-system 'ClearCase)
      (prepare-to-commit)
    nil
    )
  (do-commit)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun ghc-read-lisp (func)
  (with-temp-buffer
    (funcall func)
    (goto-char (point-min))
    (condition-case nil
        (read (current-buffer))
      (error ()))))

(defun ghc-read-lisp-list (func n)
  (with-temp-buffer
    (funcall func)
    (goto-char (point-min))
    (condition-case nil
        (let ((m (set-marker (make-marker) 1 (current-buffer)))
              ret)
          (dotimes (i n (nreverse ret))
            (ghc-add ret (read m))))
      (error ()))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Executing command
;;;

(defun ghc-boot (n)
  (if (not (executable-find ghc-hare-command))
      (message "%s not found" ghc-hare-command)
    (ghc-read-lisp-list
     (lambda ()
       (message "Initializing...")
       (call-process ghc-hare-command nil t nil "-l" "boot")
       (message "Initializing...done"))
    n)
  ))

(defun get-hare-version ()
  (interactive)
  (if (not (executable-find ghc-hare-command))
      (message "%s not found" ghc-hare-command)
    (message "HaRe version:%s"
    (ghc-read-lisp
     (lambda ()
       (message "Initializing...")
       (call-process ghc-hare-command nil t nil "--version")
       (message "Initializing...done"))
     ))
  ))

(defun get-hare-v ()
  (interactive)
  (if (not (executable-find ghc-hare-command))
      (message "%s not found" ghc-hare-command)
      (progn
         (message "Initializing...")
         (call-process ghc-hare-command nil (get-buffer-create "*HaRe*") nil "--version")
         (message "Initializing...done"))
   ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


(defun do-commit()
  "commit the refactoring result."
  (call-process ghc-hare-command nil t nil )
  (call-process ghc-hare-command nil t nil "-l" "boot")
  ;; (erl-spawn
  ;;   (erl-send-rpc wrangler-erl-node 'wrangler_preview_server 'commit (list))
  ;;   (erl-receive ()
  ;;       ((['rex ['badrpc rsn]]
  ;;         (message "Commit failed: badrpc, %s" rsn))
  ;;        (['rex ['error rsn]]
  ;;         (message "Commit failed: error, %s" rsn))
  ;;        (['rex ['ok files logmsg]]
  ;;        (condition-case nil
  ;;             (update-repository files logmsg)
  ;;          (error (message-box "The refactor monitor of Wrangler is not working properly!"))
  ;;          )
  ;;         (delete-swp-file-and-buffers files)
  ;;         (setq refactoring-committed t)
  ;;         (dolist (uf unopened-files)
  ;;           (kill-buffer (get-file-buffer-1 uf)))
  ;;         (setq unopened-files nil)
  ;;         (setq refactor-mode nil)
  ;;         (if (equal has-warning 'true)
  ;;             (progn
  ;;               (message "Refactoring succeeded, but please read the warning message in the *erl-output* buffer.")
  ;;               (setq has-warning 'false))
  ;;           nil
  ;;           ))))))
)

;; Original
;; (defun do-commit()
;;   "commit the refactoring result."
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'wrangler_preview_server 'commit (list))
;;     (erl-receive ()
;;      ((['rex ['badrpc rsn]]
;;        (message "Commit failed: badrpc, %s" rsn))
;;       (['rex ['error rsn]]
;;        (message "Commit failed: error, %s" rsn))
;;       (['rex ['ok files logmsg]]
;;       (condition-case nil
;;            (update-repository files logmsg)
;;         (error (message-box "The refactor monitor of Wrangler is not working properly!"))
;;         )
;;        (delete-swp-file-and-buffers files)
;;        (setq refactoring-committed t)
;;        (dolist (uf unopened-files)
;;          (kill-buffer (get-file-buffer-1 uf)))
;;        (setq unopened-files nil)
;;        (setq refactor-mode nil)
;;        (if (equal has-warning 'true)
;;            (progn
;;              (message "Refactoring succeeded, but please read the warning message in the *erl-output* buffer.")
;;              (setq has-warning 'false))
;;          nil
;;          ))))))



(defun delete-swp-file-and-buffers (files)
 "delete those .refactored file and buffers generated by the refactorer."
 (dolist (f files)
   (progn
     (defvar old-file-name)
     (defvar new-file-name)
     (defvar swp-file-name)
     (setq old-file-name (elt f 0))
     (setq new-file-name (elt f 1))
     (setq swp-file-name (elt f 2))
     (let ((swp-buff (get-file-buffer-1 swp-file-name)))
       (if swp-buff (kill-buffer swp-buff)
         nil))
     (delete-file  swp-file-name)
     (let ((buffer (get-file-buffer-1 old-file-name)))
       (if buffer
           (if (equal old-file-name new-file-name)
               (with-current-buffer buffer (revert-buffer nil t t))
             (with-current-buffer buffer
               (set-visited-file-name new-file-name)
               ;;(delete-file old-file-name)
               (revert-buffer nil t t)))
         nil)))))

(defun abort-changes()
  "abort the refactoring results"
  (error "not implemented")
  ;; (erl-spawn
  ;;   (erl-send-rpc wrangler-erl-node 'wrangler_preview_server 'abort (list))
  ;;   (erl-receive ()
  ;;       ((['rex ['badrpc rsn]]
  ;;         (setq refactor-mode nil)
  ;;         (message "Aborting refactoring failed: %S" rsn))
  ;;        (['rex ['error rsn]]
  ;;         (setq refactor-mode nil)
  ;;         (message "Aborting refactoring failed: %s" rsn))
  ;;        (['rex ['ok files]]
  ;;         (dolist (f files)
  ;;           (progn
  ;;             (let ((buff (get-file-buffer-1 f)))
  ;;               (if buff (kill-buffer (get-file-buffer-1 f))
  ;;                 nil))
  ;;             (delete-file f)))
  ;;         (dolist (uf unopened-files)
  ;;           (kill-buffer (get-file-buffer-1 uf)))
  ;;         (setq unopened-files nil)
  ;;         (setq refactor-mode nil)
  ;;         (message "Refactoring aborted."))))))
)


;; (defun commit-or-abort()
;;   "commit or abort the refactoring result."
;;   (if (y-or-n-p "Do you want to perform the changes?")
;;       (commit)
;;      (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'wrangler_preview_server 'abort (list))
;;       (erl-receive ()
;;           ((['rex ['badrpc rsn]]
;;             (setq refactor-mode nil)
;;             (message "Aborting refactoring failed: %S" rsn))
;;            (['rex ['error rsn]]
;;             (setq refactor-mode nil)
;;             (message "Aborting refactoring failed: %s" rsn))
;;            (['rex ['ok files]]
;;             (dolist (f files)
;;               (progn
;;                 (let ((buff (get-file-buffer-1 f)))
;;                   (if buff (kill-buffer (get-file-buffer-1 f))
;;                     nil))
;;                 (delete-file f)))
;;             (dolist (uf unopened-files)
;;               (kill-buffer (get-file-buffer-1 uf)))
;;             (setq unopened-files nil)
;;             (setq refactor-mode nil)
;;             (message "Refactoring aborted.")))))))


(add-hook 'ediff-quit-hook 'my-ediff-qh)


(defvar refactor-menu-items
  `(
    ;; ("Rename Variable Name" erl-refactor-rename-var)
    ;; ("Rename Function Name" erl-refactor-rename-fun)
    ;; ("Rename Module Name" erl-refactor-rename-mod)
    ;; ("Generalise Function Definition" erl-refactor-generalisation)
    ("Move Function to Another Module" hare-refactor-move-fun)
    ;; ("Function Extraction" erl-refactor-fun-extraction)
    ;; ("Introduce New Variable"  erl-refactor-new-variable)
    ;; ("Inline Variable" erl-refactor-inline-variable)
    ;; ("Fold Expression Against Function" erl-refactor-fold-expression)
    ;; ("Tuple Function Arguments" erl-refactor-tuple-funpar)
    ;; ("Unfold Function Application" erl-refactor-unfold-fun)
    nil
    ("Introduce a Macro" erl-refactor-new-macro)
    ("Fold Against Macro Definition" erl-refactor-fold-against-macro)
    nil
    ;; ("Refactorings for QuickCheck"
    ;;  (
    ;;   ("Introduce ?LET" erl-refactor-introduce-let)
    ;;   ("Merge ?LETs"    erl-refactor-merge-let)
    ;;   ("Merge ?FORALLs"   erl-refactor-merge-forall)
    ;;   ("eqc_statem State Data to Record" erl-refactor-eqc-statem-to-record)
    ;;   ("eqc_fsm State Data to Record" erl-refactor-eqc-fsm-to-record)
    ;;   ("Test Cases to Property"  erl-refactor-test-cases-to-property)
    ;;   ("Refactor Bug PreCond"  erl-refactor-bug-precond)
    ;;   ))
    nil
    ;; ("Process Refactorings (Beta)"
    ;;  (
    ;;   ("Rename a Process" erl-refactor-rename-process)
    ;;   ("Add a Tag to Messages"  erl-refactor-add-a-tag)
    ;;   ("Register a Process"   erl-refactor-register-pid)
    ;;   ("From Function to Process" erl-refactor-fun-to-process)
    ;;   ))
    ;; ("Normalise Record Expression" erl-refactor-normalise-record-expr)
    ;; ("Partition Exported Functions"  erl-wrangler-code-inspector-partition-exports)
    ;; ("gen_fsm State Data to Record" erl-refactor-gen-fsm-to-record)
    ;; nil
    ;; ("gen_refac Refacs"  (gen_refac_menu_items))
    ;; ("gen_composite_refac Refacs" (gen_composite_refac_menu_items))
    ;; nil
    ;; ("My gen_refac Refacs" (my_gen_refac_menu_items))
    ;; ("My gen_composite_refac Refacs" (my_gen_composite_refac_menu_items))
    ;; nil
    ;; ("Apply Adhoc Refactoring"  apply-adhoc-refac)
    ;; ("Apply Composite Refactoring" apply-composite-refac)
    nil
    ("Add/Remove Menu Items"
     (
       ("Add To My gen_refac Refacs" add_to_my_gen_refac_menu_items)
       ("Add To My gen_composite_refac Refacs" add_to_my_gen_composite_refac_menu_items)
       nil
        ("Remove from My gen_refac Refacs" remove_from_my_gen_refac_menu_items)
        ("Remove from My gen_composite_refac Refacs" remove_from_my_gen_composite_refac_menu_items)
    ))))

(defvar inspector-menu-items
  '(("Instances of a Variable" erl-wrangler-code-inspector-var-instances)
    ("Calls to a Function" erl-wrangler-code-inspector-caller-funs)
    ("Dependencies of a Module" erl-wrangler-code-inspector-caller-called-mods)
    ("Nested If Expressions" erl-wrangler-code-inspector-nested-ifs)
    ("Nested Case Expressions" erl-wrangler-code-inspector-nested-cases)
    ("Nested Receive Expression" erl-wrangler-code-inspector-nested-receives)
    ("Long Functions" erl-wrangler-code-inspector-long-funs)
    ("Large Modules" erl-wrangler-code-inspector-large-mods)
    ;;("Component Extraction Suggestion" erl-wrangler-code-component-extraction)
    ("Show Non Tail Recursive Servers" erl-wrangler-code-inspector-non-tail-recursive-servers)
    ("Incomplete Receive Patterns" erl-wrangler-code-inspector-no-flush)
    nil
    ("Apply Adhoc Code Inspection" apply-my-code-inspection)
    ))

(defvar wrangler-menu-items
  `(("Refactor" ,refactor-menu-items)
    ("Inspector" ,inspector-menu-items)
    nil
    ("Undo" hare-refactor-undo)
    nil
    ("Similar Code Detection"
     (("Detect Similar Code in Current Buffer" erl-refactor-inc-sim-code-detection-in-buffer)
      ("Detect Similar Code in Dirs" erl-refactor-inc-sim-code-detection-in-dirs)
      ("Similar Expression Search in Current Buffer" erl-refactor-similar-expression-search)
      ("Similar Expression Search in Dirs" erl-refactor-similar-expression-search-in-dirs)
      ;;  ("Detect Similar Code in Current Buffer (Old)" erl-refactor-sim-code-detection-in-buffer)
      ;;  ("Detect Similar Code in Dirs (Old)" erl-refactor-sim-code-detection-in-dirs)
      ))
     nil
     ("Module Structure"
      (("Generate Function Callgraph" erl-wrangler-code-inspector-callgraph)
       ("Generate Module Graph" erl-wrangler-code-inspector-module-graph)
       ("Cyclic Module Dependency" erl-wrangler-code-inspector-cyclic-graph)
       ("Module Dependency via Only Internal Functions" erl-wrangler-code-inspector-improper-module-dependency)))
    nil
    ("API Migration"
     (("Generate API Migration Rules"  erl-refactor-generate-migration-rules)
      ("Apply API Migration to Current File" erl-refactor-apply-api-migration-file)
      ("Apply API Migration to Dirs" erl-refactor-apply-api-migration-dirs)
      nil
      ("From Regexp to Re"  erl-refactor-regexp-to-re)
      ))
    nil
    ("Skeletons"
     (("gen_refac Skeleton"  tempo-template-gen-refac)
      ("gen_composite_refac Skeleton" tempo-template-gen-composite-refac)
      ))
    nil
    ("Customize HaRe" hare-customize)
    nil
    ("Version" haskell-refactor-version)
    ))


(global-set-key (kbd "C-c C-r") 'toggle-haskell-refactorer)

;; (add-hook 'erl-nodedown-hook 'wrangler-nodedown)

;; (defun wrangler-nodedown(node)
;;   ( if (equal node wrangler-erl-node)
;;      (progn (hare-menu-remove)
;;             (message "Wrangler stopped.")
;;      )
;;    nil))

(defun toggle-haskell-refactorer ()
  (interactive)
  (if (get-buffer "*HaRe-Shell*")
      (call-interactively 'haskell-refactorer-off)
    (call-interactively 'haskell-refactorer-on)))

(defun start-hare-app()
   (interactive)
   (hare-menu-init)
   )
;; (defun start-hare-app()
;;   (interactive)
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'application 'start (list 'wrangler))
;;     (erl-receive()
;;         ((['rex 'ok]
;;           (hare-menu-init)
;;           (message "Wrangler started.")
;;           )
;;          (['rex ['error ['already_started app]]]
;;           (message "Wrangler failed to start: another Wrangler application is running.")
;;           )
;;          (['rex ['error rsn]]
;;           (message "Wrangler failed to start:%s" rsn)
;;         )))))

(defun haskell-refactorer-off()
  (interactive)
  (hare-menu-remove)
  (if (not (get-buffer "*HaRe-Shell*"))
      t

      t
    ;; (progn
    ;;   (erl-spawn
    ;;     (erl-send-rpc wrangler-erl-node 'application 'stop (list 'wrangler))
    ;;     (erl-receive()
    ;;         ((['rex 'ok]
    ;;           (kill-buffer "*HaRe-Shell*")
    ;;           (message "Wrangler stopped"))
    ;;          (['rex ['error rsn]]
    ;;           (kill-buffer "*HaRe-Shell*")
    ;;           (message "Wrangler stopped"))
    ;;          ))))
    ))


(defun haskell-refactorer-off-1()
  (interactive)
  (hare-menu-remove)
  (if (not (get-buffer "*HaRe-Shell*"))
      t
    (progn
      (kill-buffer "*HaRe-Shell*"))
    ;; (progn
    ;;   (erl-spawn
    ;;     (erl-send-rpc wrangler-erl-node 'application 'stop (list 'wrangler))
    ;;     (erl-receive()
    ;;         ((['rex 'ok]
    ;;           (kill-buffer "*HaRe-Shell*")
    ;;          )
    ;;          (['rex ['error rsn]]
    ;;           (kill-buffer "*HaRe-Shell*")
    ;;           )))))))
   ))


(defun haskell-refactorer-on()
  (interactive)
  (message "starting Wrangler...")
  ;; (check-erl-cookie)
  (if   (get-buffer "*HaRe-Shell*")
      (haskell-refactorer-off-1)
    t)
  ;; (setq wrangler-erl-node-string (concat "wrangler" (number-to-string (random 1000)) "@localhost"))
  ;; (setq wrangler-erl-node (intern  wrangler-erl-node-string))
  ;; (sleep-for 1.0)
  (save-window-excursion
    (hare-shell))
  (sleep-for 1.0)
  ;; (erl-spawn
  ;;   (erl-send-rpc wrangler-erl-node 'code 'ensure_loaded (list 'distel))
  ;;   (erl-receive()
  ;;       ((['rex res]
  ;;         t))))
  ;; (sleep-for 1.0)
  (start-wrangler-app))


;; (defun hare-shell()
;;   "Start a shell for HaRe"
;;   (interactive)
;;   (call-interactively hare-shell-function))

;; (defun check-erl-cookie()
;;   "check if file .erlang.cookie exists."
;;   (let ((cookie-file  (expand-file-name (concat (getenv "HOME") "/.erlang.cookie"))))
;;     (if (file-exists-p  cookie-file)
;;         t
;;       (error "File %s does not exist; please create it first, then restart Wrangler." 
;;              cookie-file))))

;; (defvar hare-shell-function 'hare-shell
;;   "Command to execute start a new Haskell Refactorer shell"
;; )

;; (defvar hare-shell-type 'newshell
;;         "variable need to make HaRe start with Ubuntu"
;; )

;; (defun hare-shell()
;;   "Run a HaRe shell"
;;   (interactive)
;;   (require 'comint)
;;   ;; (setq opts (list "-name" wrangler-erl-node-string
;;   ;;                  "-pa" (expand-file-name (concat (getenv "HOME") "/.wrangler/ebin"))
;;   ;;                  "-setcookie" (erl-cookie)
;;   ;;                  "-newshell" "-env" "TERM" "vt100"))
;;   (setq opts (list ""))
;;   (setq hare-shell-buffer
;;         (apply 'make-comint
;;                "HaRe-Shell" "erl"
;;                nil opts))
;;   (setq hare-shell-process
;;         (get-buffer-process hare-shell-buffer))
;;   (switch-to-buffer hare-shell-buffer)
;;   (if (and (not (equal system-type 'windows-nt))
;;            (equal hare-shell-type 'newshell))
;;       (setq comint-process-echoes t)))

(defun haskell-refactor-version()
  (interactive)
  (message "HaRe version 1.0"))

(setq hare-version  "(hare-1.0) ")

(defun hare-menu-init()
  "Init HaRe menus."
  (interactive)
  (define-key erlang-mode-map "\C-c\C-w_"  'hare-refactor-undo)
  ;; (define-key erlang-mode-map "\C-c\C-wb" 'erl-wrangler-code-inspector-var-instances)
  ;; (define-key erlang-mode-map "\C-c\C-we" 'remove-highlights)
  ;; (define-key erlang-mode-map "\C-c\C-wrv" 'erl-refactor-rename-var)
  ;; (define-key erlang-mode-map "\C-c\C-wrf"  'erl-refactor-rename-fun)
  ;; (define-key erlang-mode-map "\C-c\C-wrm"  'erl-refactor-rename-mod)
  ;; (define-key erlang-mode-map "\C-c\C-g"    'erl-refactor-generalisation)
  (define-key erlang-mode-map "\C-c\C-wm"   'hare-refactor-move-fun)
  ;; (define-key erlang-mode-map "\C-c\C-wnv"  'erl-refactor-new-variable)
  ;; (define-key erlang-mode-map "\C-c\C-wi"  'erl-refactor-inline-variable)
  ;; (define-key erlang-mode-map "\C-c\C-wnf"  'erl-refactor-fun-extraction)
  ;; (define-key erlang-mode-map "\C-c\C-wff"   'erl-refactor-fold-expression)
  ;; (define-key erlang-mode-map "\C-c\C-wt"  'erl-refactor-tuple-funpar)
  ;; (define-key erlang-mode-map "\C-c\C-wu"  'erl-refactor-unfold-fun)
  ;; (define-key erlang-mode-map "\C-c\C-wnm"  'erl-refactor-new-macro)
  ;; (define-key erlang-mode-map "\C-c\C-wfm"  'erl-refactor-fold-against-macro)
  ;; (define-key erlang-mode-map "\C-c\C-ws"  'erl-refactor-similar-expression-search)
  ;; (define-key erlang-mode-map "\C-c\C-wcb"  'erl-refactor-inc-sim-code-detection-in-buffer)
  ;; (define-key erlang-mode-map "\C-c\C-wcd"  'erl-refactor-inc-sim-code-detection-in-dirs)
  (erlang-menu-install "Wrangler" wrangler-menu-items erlang-mode-map t)
  )

(if (file-exists-p hare_ext)
    (load  hare_ext)
    nil)

(defun hare-menu-remove()
  "Remove Wrangler menus."
  (interactive)
  (define-key erlang-mode-map "\C-c\C-w\C-_"  nil)
  (define-key erlang-mode-map  "\C-c\C-w\C-b" nil)
  (define-key erlang-mode-map "\C-c\C-w\C-e"  nil)
  (cond (erlang-xemacs-p
         (erlang-menu-uninstall '("Wrangler") wrangler-menu-items erlang-mode-map t))
        (t
         (erlang-menu-uninstall "Wrangler" wrangler-menu-items erlang-mode-map t))
        ))

(defun erlang-menu-uninstall (name items keymap &optional popup)
  "UnInstall a menu in Emacs or XEmacs based on an abstract description."
  (cond (erlang-xemacs-p
         (delete-menu-item name))
        ((>= erlang-emacs-major-version 19)
         (define-key keymap (vector 'menu-bar (intern name))
           'undefined))
        (t nil)))

(defun hare-refactor-undo()
  "Undo the latest refactoring."
  (interactive)
  (let (buffer (current-buffer))
    (if (y-or-n-p "Undo a refactoring will also undo the editings done after the refactoring, undo anyway?")
        (progn
          (if (equal version-control-system 'ClearCase)
              nil
              ;; (erl-spawn
              ;;   (erl-send-rpc wrangler-erl-node 'wrangler_undo_server 'files_to_change (list))
              ;;   (erl-receive (buffer)
              ;;       ((['rex ['badrpc rsn]]
              ;;         (message "Undo failed: %S" rsn))
              ;;        (['rex ['error rsn]]
              ;;         (message "Undo failed: %s" rsn))
              ;;        (['rex ['ok files-to-recover  filenames-to-recover]]
              ;;         (progn
              ;;           (setq files-to-write files-to-recover)
              ;;           (setq files-to-rename filenames-to-recover)
              ;;           (prepare-to-commit) )))))
            nil
            )
          ;; (erl-spawn
          ;;   (erl-send-rpc wrangler-erl-node 'wrangler_undo_server 'undo_emacs (list))
          ;;   (erl-receive (buffer)
          ;;       ((['rex ['badrpc rsn]]
          ;;         (message "Undo failed: %S" rsn))
          ;;        (['rex ['error rsn]]
          ;;         (message "Undo failed: %s" rsn))
          ;;        (['rex ['ok modified1 logmsg curfile]]
          ;;         (dolist (f modified1)
          ;;           (let ((oldfilename (car f))
          ;;                 (newfilename (car (cdr f)))
          ;;                 (buffer (get-file-buffer-1 (car (cdr f)))))
          ;;             (if buffer (if (not (equal oldfilename newfilename))
          ;;                            (with-current-buffer buffer
          ;;                              (progn (set-visited-file-name oldfilename)
          ;;                                     (revert-buffer nil t t)))
          ;;                          (with-current-buffer buffer (revert-buffer nil t t)))
          ;;               nil)))
          ;;         (let ((dir (is-a-monitored-file curfile)))
          ;;           (if (equal nil dir)
          ;;               nil
          ;;             (cond
          ;;              ((equal version-control-system 'ClearCase)
          ;;               (let* ((reason (read-string "Reason for undo: " nil nil "" nil))
          ;;                     (new-logmsg (concat "UNDO: " logmsg "Reason: " reason "\n")))
          ;;                 (add-logmsg-to-logfile-clearcase new-logmsg)))
          ;;              ((or (equal version-control-system 'Git)
          ;;                   (equal version-control-system 'SVN))
          ;;               (let ((reason (read-string "Reason for undo: " nil nil "" nil)))
          ;;                 (write-to-refac-logfile dir (concat "UNDO: " logmsg "Reason: " reason "\n") "UNDO"))
          ;;               )
          ;;              (t nil))
          ;;             (message "Undo succeeded")))))))
          )
      (message "Undo aborted."))
    )
  )


(defun preview-commit-cancel(current-file-name modified renamed)
  "preview, commit or cancel the refactoring result"
  (setq files-to-write modified)
  (setq files-to-rename renamed)
  (preview-commit-cancel-1 current-file-name modified)
  )


(defun preview-commit-cancel-1 (current-file-name modified)
  "preview, commit or cancel the refactoring result"
  (let ((answer (read-char-spec-1 "Do you want to preview(p)/commit(c)/cancel(n) the changes to be performed?(p/c/n):"
                  '((?p p "Answer p to preview the changes")
                    (?c c "Answer c to commit the changes without preview")
                    (?n n "Answer n to abort the changes")))))
    (cond ((equal answer 'p)
           (defvar first-file)
           (setq first-file (car modified))
           (setq modified-files (cdr modified))
           (hare-ediff first-file
                           (concat (file-name-sans-extension first-file)
                                   (file-name-extension first-file t) ".refactored")))
          ((equal answer 'c)
           (commit))
          ((equal answer 'n)
           (abort-changes)))))




(defun revert-all-buffers()
  "Refreshs all open buffers from their respective files"
      (interactive)
      (let* ((list (buffer-list))
             (buffer (car list)))
        (while buffer
          (if (string-match "\\*" (buffer-name buffer))
              (progn
                (setq list (cdr list))
                (setq buffer (car list)))
            (progn
              (set-buffer buffer)
              (if (file-exists-p (buffer-file-name buffer))
                  (revert-buffer t t t)
                nil)
              (setq list (cdr list))
              (setq buffer (car list)))))))


(defun current-buffer-saved(buffer)
  (let* ((n (buffer-name buffer)) (n1 (substring n 0 1)))
    (if (and (not (or (string= " " n1) (string= "*" n1))) (buffer-modified-p buffer))
        (if (y-or-n-p "The current buffer has been changed, and Wrangler needs to save it before refactoring, continue?")
            (progn (save-buffer)
                   t)
          nil)
      t)))

(defun buffers-saved()
  (let (changed)
      (dolist (b (buffer-list) changed)
        (let* ((n (buffer-name b)) (n1 (substring n 0 1)))
          (if (and (not (or (string= " " n1) (string= "*" n1))) (buffer-modified-p b))
              (setq changed (cons (buffer-name b) changed)))))
      (if changed
          (if (y-or-n-p (format "There are modified buffers: %s, which Wrangler needs to save before refactoring, continue?" changed))
              (progn
                (save-some-buffers t)
                t)
            nil)
        t)
      ))


(defun buffers-changed-warning()
  (let (changed)
    (dolist (b (buffer-list) changed)
      (let* ((n (buffer-name b)) (n1 (substring n 0 1)))
        (if (and (not (or (string= " " n1) (string= "*" n1))) (buffer-modified-p b))
            (setq changed (cons (buffer-name b) changed)))))
    (if changed
        (if (y-or-n-p (format "Undo a refactoring could also undo the editings done after the refactoring, undo anyway?"))
            t
          nil)
      t)
    ))


;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (defun erl-refactor-rename-var-composite(args)
;;   "rename a function name; used in composite refactoring mode."
;;   (interactive)
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                   (list 'refac_rename_var 'rename_var_composite args ))
;;     (erl-receive ()
;;         ((['rex ['badrpc rsn]]
;;           ['badrpc rsn])
;;          (['rex ['error rsn]]
;;           ['error rsn])
;;          (['rex ['ok current-file-name line-no col-no new-name search-paths editor tab-width]]
;;           (erl-refactor-rename-var-1 current-file-name line-no col-no new-name search-paths editor tab-width)
;;          )))))

;; (defun erl-refactor-rename-var (name)
;;   "Rename an identified variable name."
;;   (interactive (list (read-string "New name: ")))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;         (erl-refactor-rename-var-1 current-file-name line-no column-no name hare-search-paths 'emacs tab-width)
;;       (message "Refactoring aborted."))))


;; (defun erl-refactor-rename-var-1(current-file-name line-no column-no name hare-search-paths editor tab-width)
;;   "Rename an identified variable name."
;;   (setq composite-refac-p (equal editor 'composite_emacs))
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                   (list 'rename_var
;;                         (list current-file-name line-no column-no name
;;                               hare-search-paths editor tab-width)
;;                         hare-search-paths))
;;     (erl-receive (line-no column-no current-file-name)
;;         ((['rex result]
;;           (process-result current-file-name result line-no column-no composite-refac-p))))))

;; (defun erl-refactor-rename-fun-composite(args)
;;   "rename a function name; used in composite refactoring mode."
;;   (interactive)
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                   (list 'refac_rename_fun 'rename_fun_by_name  args))
;;     (erl-receive (args)
;;         ((['rex result]
;;           (process-result (car args) result 0 0 t)
;;           ))
;;       )))
;; (defun erl-refactor-rename-fun (name)
;;   "Rename an identified function name."
;;   (interactive (list (read-string "New name: ")))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;         (erl-refactor-rename-fun-1 current-file-name line-no column-no name hare-search-paths  'emacs tab-width)
;;       (message "Refactoring aborted."))))

;; (defun erl-refactor-rename-fun-1 (current-file-name line-no column-no name hare-search-paths  editor tab-width)
;;   "Rename an identified function name."
;;   (setq composite-refac-p (equal editor 'composite_emacs))
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                   (list 'rename_fun
;;                         (list current-file-name line-no column-no name
;;                               hare-search-paths editor tab-width)
;;                         hare-search-paths))
;;     (erl-receive (line-no column-no current-file-name name editor composite-refac-p)
;;         ((['rex ['warning msg]]
;;           (progn
;;             (if (y-or-n-p msg)
;;                 (erl-spawn
;;                   (erl-send-rpc wrangler-erl-node 'wrangler_refacs
;;                                 'try_refac (list 'wrangler_refacs  'rename_fun_1 
;;                                                        (list current-file-name line-no column-no name 
;;                                                              hare-search-paths editor tab-width)))
;;                   (erl-receive (line-no column-no current-file-name composite-refac-p)
;;                       ((['rex result]
;;                         (process-result current-file-name result line-no column-no composite-refac-p)))))
;;               (process-result current-file-name (list 'abort) line-no column-no composite-refac-p)
;;               )))
;;          (['rex result]
;;           (process-result current-file-name result line-no column-no composite-refac-p))
;;          ))))



;; (defun erl-refactor-rename-mod (name)
;;   "Rename the current module name."
;;   (interactive (list (read-string "New module name: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;   (if (buffers-saved)
;;       (erl-spawn
;;      (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                       (list 'rename_mod (list current-file-name name hare-search-paths 'emacs tab-width)
;;                             hare-search-paths))
;;         (erl-receive (buffer name current-file-name)
;;          ((['rex ['badrpc rsn]]
;;            (message "Refactoring failed: %S" rsn))
;;           (['rex ['error rsn]]
;;            (message "Refactoring failed: %s" rsn))
;;           (['rex ['warning msg]]
;;            (progn
;;              (if (y-or-n-p msg)
;;                  (erl-spawn
;;                    (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                                     (list 'refac_rename_mod 'rename_mod_1
;;                                           (list current-file-name name hare-search-paths tab-width 'false 'emacs)))
;;                    (erl-receive (current-file-name)
;;                        ((['rex ['badrpc rsn]]
;;                          (message "Refactoring failed: %S" rsn))
;;                         (['rex ['error rsn]]
;;                          (message "Refactoring failed: %s" rsn))
;;                         (['rex ['ok modified renamed  warning]]
;;                          (progn
;;                            (setq has-warning warning)
;;                            (preview-commit-cancel current-file-name modified renamed)
;;                          )))
;;                    (message "Refactoring aborted.")
;;                    )))))
;;           (['rex ['question msg]]
;;            (progn
;;              (if (y-or-n-p msg)
;;                (erl-spawn
;;                  (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                                   (list 'refac_rename_mod 'rename_mod_1
;;                                         (list current-file-name name hare-search-paths tab-width 'true 'emacs)))
;;                  (erl-receive (current-file-name)
;;                      ((['rex ['badrpc rsn]]
;;                        (message "Refactoring failed: %S" rsn))
;;                       (['rex ['error rsn]]
;;                        (message "Refactoring failed: %s" rsn))
;;                       (['rex ['ok modified renamed warning]]
;;                        (progn
;;                          (setq has-warning warning)
;;                          (preview-commit-cancel current-file-name modified renamed))
;;                        ))))
;;              (erl-spawn
;;                (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                                 (list 'refac_rename_mod 'rename_mod_1
;;                                       (list current-file-name name hare-search-paths tab-width 'false 'emacs)))
;;                  (erl-receive (current-file-name)
;;                      ((['rex ['badrpc rsn]]
;;                        (message "Refactoring failed: %S" rsn))
;;                       (['rex ['error rsn]]
;;                        (message "Refactoring failed: %s" rsn))
;;                       (['rex ['ok modified renamed warning]]
;;                        (progn
;;                          (setq has-warning warning)
;;                          (preview-commit-cancel current-file-name modified renamed)
;;                          )))))

;;              )))
;;         (['rex ['ok modified renamed warning]]
;;          (progn
;;            (setq has-warning warning)
;;            (preview-commit-cancel current-file-name modified renamed)
;;            )))))
;;     (message "Refactoring aborted."))))


;; (defun erl-refactor-rename-process(name)
;;   "Rename a registered process."
;;   (interactive (list (read-string "New name: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                         (list 'rename_process
;;                               (list current-file-name line-no column-no name hare-search-paths 'emacs tab-width)
;;                               hare-search-paths))
;;       (erl-receive (name current-file-name line-no column-no)
;;        ((['rex ['badrpc rsn]]
;;          (message "Refactoring failed: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Refactoring failed: %s" rsn))
;;         (['rex ['undecidables oldname logmsg]]
;;         (if (y-or-n-p "Do you want to continue the refactoring?")
;;             (erl-spawn
;;               (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_rename_process 'rename_process_1
;;                             (list current-file-name oldname name hare-search-paths tab-width 'emacs logmsg)))
;;               (erl-receive (current-file-name line-no column-no)
;;                   ((['rex ['badrpc rsn]]
;;                     (message "Refactoring failed: %S" rsn))
;;                    (['rex ['error rsn]]
;;                     (message "Refactoring failed: %s" rsn))
;;                    (['rex ['ok modified]]
;;                     (progn
;;                       (preview-commit-cancel current-file-name modified nil)
;;                       (with-current-buffer (get-file-buffer-1 current-file-name)
;;                         (goto-line line-no)
;;                         (goto-column column-no)))))))
;;           (message "Refactoring aborted!")))
;;         (['rex ['ok modified]]
;;          (progn
;;            (preview-commit-cancel current-file-name modified nil)
;;            (with-current-buffer (get-file-buffer-1 current-file-name)
;;              (goto-line line-no)
;;              (goto-column column-no))))
;;         )))
;;       (message "Refactoring aborted!"))))




;; (defun erl-refactor-unfold-fun()
;;   "Unfold a function application."
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                         (list 'unfold_fun_app (list current-file-name (list line-no column-no) hare-search-paths 'emacs tab-width)
;;                               hare-search-paths))
;;        (erl-receive (line-no column-no current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok modified]]
;;              (progn
;;                (if (equal modified nil)
;;                    (message "Refactoring finished, and no file has been changed.")
;;                  (preview-commit-cancel current-file-name modified nil))
;;                (with-current-buffer (get-file-buffer-1 current-file-name)
;;                  (goto-line line-no)
;;                  (goto-column column-no))))
;;             )))
;;       (message "Refactoring aborted."))))


;; (defun erl-refactor-register-pid(name start end)
;;   "Register a process with a user-provied name."
;;   (interactive (list (read-string "process name: ")
;;                   (region-beginning)
;;                   (region-end)
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end)))
;;     (if (buffers-saved)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                         (list 'register_pid
;;                               (list current-file-name (list start-line-no start-col-no)
;;                                     (list end-line-no (- end-col-no 1)) name
;;                                     hare-search-paths 'emacs tab-width)
;;                               hare-search-paths))
;;        (erl-receive (current-file-name start-line-no start-col-no end-line-no end-col-no name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['unknown_pnames regpids logmsg]]
;;              (if (y-or-n-p "Do you want to continue the refactoring?")
;;                  (erl-spawn
;;                    (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_register_pid 'register_pid_1
;;                                  (list current-file-name start-line-no start-col-no end-line-no (- end-col-no 1) name regpids hare-search-paths tab-width logmsg)))
;;                    (erl-receive (current-file-name start-line-no start-col-no end-line-no end-col-no name)
;;                        ((['rex ['badrpc rsn]]
;;                          (message "Refactoring failed: %S" rsn))
;;                         (['rex ['error rsn]]
;;                          (message "Refactoring failed: %s" rsn))
;;                         (['rex ['unknown_pids pars logmsg]]
;;                          (if (y-or-n-p "Do you want to continue the refactoring?")
;;                              (erl-spawn
;;                                (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_register_pid 'register_pid_2
;;                                              (list current-file-name start-line-no start-col-no end-line-no (- end-col-no 1) name hare-search-paths tab-width logmsg)))
;;                                (erl-receive (current-file-name start-line-no start-col-no)
;;                                    ((['rex ['badrpc rsn]]
;;                                      (message "Refactoring failed: %S" rsn))
;;                                     (['rex ['error rsn]]
;;                                      (message "Refactoring failed: %s" rsn))
;;                                     (['rex ['ok modified]]
;;                                      (progn
;;                                        (preview-commit-cancel current-file-name modified nil)
;;                                        (with-current-buffer (get-file-buffer-1 current-file-name)
;;                                          (goto-line start-line-no)
;;                                          (goto-column start-column-no)))
;;                                      ))))
;;                            (message "Refactoring aborted!")))
;;                         (['rex ['ok modified]]
;;                          (progn
;;                            (preview-commit-cancel current-file-name modified nil)
;;                            (with-current-buffer (get-file-buffer-1 current-file-name)
;;                              (goto-line start-line-no)
;;                              (goto-column start-column-no)))
;;                          ))))
;;                (message "Refactoring aborted!")))
;;             (['rex ['unknown_pids pars logmsg]]
;;              (if (y-or-n-p "Do you want to continue the refactoring?")
;;                  (erl-spawn
;;                    (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_register_pid 'register_pid_2
;;                                  (list current-file-name start-line-no start-col-no end-line-no (- end-col-no 1) name hare-search-paths tab-width logmsg)))
;;                    (erl-receive (currnet-file-name start-line-no start-col-no)
;;                        ((['rex ['badrpc rsn]]
;;                          (message "Refactoring failed: %S" rsn))
;;                         (['rex ['error rsn]]
;;                          (message "Refactoring failed: %s" rsn))
;;                         (['rex ['ok modified]]
;;                          (progn
;;                            (preview-commit-cancel current-file-name modified nil)
;;                            (with-current-buffer (get-file-buffer-1 current-file-name)
;;                              (goto-line start-line-no)
;;                              (goto-column start-column-no)))
;;                          ))))
;;                (message "Refactoring aborted!")))
;;             (['rex ['ok modified]]
;;               (progn
;;                 (preview-commit-cancel current-file-name modified nil)
;;                 (with-current-buffer (get-file-buffer-1 current-file-name)
;;                   (goto-line start-line-no)
;;                   (goto-column start-column-no))))
;;             )))
;;        (message "Refactoring aborted."))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun hare-refactor-lift-one ()
  "Lift a definition one level."
  (interactive)
  (let ((current-file-name (buffer-file-name))
        (line-no           (current-line-no))
        (column-no         (current-column-no))
        (buffer (current-buffer)))
    (if (buffers-saved)
        (hare-refactor-lift-one-1 current-file-name line-no column-no hare-search-paths 'emacs tab-width)
      (message "Refactoring aborted."))))


(defun hare-refactor-lift-one-1 (current-file-name line-no column-no search-paths editor tab-width)
  "Lift a definition one level."
  (let (composite-refac-p name msg result)
  (setq composite-refac-p (equal editor 'composite_emacs))

  (let ((res
        (ghc-read-lisp
         (lambda ()
           (message "Running...")
           ;(call-process ghc-hare-command nil (get-buffer-create "*HaRe*") nil
           (call-process ghc-hare-command nil t nil
                         "liftOneLevel" current-file-name
                         (number-to-string line-no) (number-to-string column-no))
           (message "Running...done"))
         )))
    (with-current-buffer (get-buffer-create "*HaRe*") (insert (prin1-to-string res)))
    (message "Res=%s" res)
    (process-result current-file-name res line-no column-no composite-refac-p)
   )
  ))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (defun erl-refactor-move-fun-composite(args)
;;   "Move a function specified by mfa to another module."
;;   (interactive)
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                   (list 'refac_move_fun 'move_fun_by_name args))
;;     (erl-receive (args)
;;         ((['rex ['ok current-file-name line-no col-no target-file-name search-paths]]
;;           (hare-refactor-move-fun-1 current-file-name line-no col-no target-file-name 
;;                                    search-paths 'composite_emacs tab-width))
;;          (['rex result]
;;           (process-result (car args) result 0 0 t))
;;          ))))

;; (defun hare-refactor-move-fun (name)
;;   "Move a function definition from one module to another."
;;   (interactive (list (read-string "Target Module name: ")))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;         (hare-refactor-move-fun-1 current-file-name line-no column-no name hare-search-paths 'emacs tab-width)
;;       (message "Refactoring aborted."))))

;; (defun hare-refactor-move-fun-1 (current-file-name line-no column-no name search-paths  editor tab-width)
;;   "Move a function definition from one module to another."
;;   (setq composite-refac-p (equal editor 'composite_emacs))
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac (list 'move_fun
;;                   (list current-file-name line-no column-no name search-paths  editor tab-width)
;;                   hare-search-paths))
;;     (erl-receive (line-no column-no  name current-file-name editor  search-paths)
;;         ((['rex ['question msg]]
;;           (progn
;;             (if (y-or-n-p msg)
;;                 (erl-spawn
;;                   (erl-send-rpc wrangler-erl-node 'refac_move_fun 'move_fun_1
;;                                 (list current-file-name line-no column-no name 'true 
;;                                       search-paths  editor tab-width))
;;                   (erl-receive (name line-no column-no current-file-name editor  search-paths)
;;                       ((['rex ['warning msg]]
;;                         (progn
;;                           (if (y-or-n-p msg)
;;                               (erl-spawn
;;                                 (erl-send-rpc wrangler-erl-node 'refac_move_fun 'move_fun_1 
;;                                               (list current-file-name line-no column-no name 'false 
;;                                                     search-paths  editor tab-width))
;;                                 (erl-receive (line-no column-no current-file-name)
;;                                     ((['rex result]
;;                                       (process-result current-file-name result line-no column-no composite-refac-p))
;;                                      ))))
;;                           (process-result current-file-name (list 'abort) line-no column-no composite-refac-p)
;;                          ))
;;                        (['rex result]
;;                         (process-result current-file-name result line-no column-no composite-refac-p)
;;                         ))))
;;                (process-result current-file-name (list 'abort) line-no column-no composite-refac-p)
;;                )))
;;          (['rex ['warning msg]]
;;           (if (y-or-n-p msg)
;;               (erl-spawn
;;                 (erl-send-rpc wrangler-erl-node 'refac_move_fun 'move_fun_1
;;                               (list current-file-name line-no column-no name 'false 
;;                                     search-paths  editor tab-width))
;;                 (erl-receive (line-no column-no current-file-name)
;;                     ((['rex result]
;;                         (process-result current-file-name result line-no column-no composite-refac-p))
;;                      )))
;;             (process-result current-file-name (list 'abort) line-no column-no composite-refac-p)
;;             ))
;;          (['rex result]
;;           (process-result current-file-name result line-no column-no composite-refac-p))
;;          ))))

(defun process-result(current-file-name result line-no column-no composite-refac-p)
  "process the result return by refactoring"
  (let (rsn modified renamed warning name_change)
  (if composite-refac-p
      (cond ((equal (elt result 0) 'badrpc)
             (setq rsn (elt result 1))
             (message "Refactoring failed: %S" rsn)
             (apply-refac-cmds current-file-name (list 'error rsn)))
            ((equal (elt result 0) 'error)
             (setq rsn (elt result 1))
             (message "Refactoring failed: %S" rsn)
             (apply-refac-cmds current-file-name (list 'error rsn)))
            ((equal (elt result 0) 'ok)
             (setq modified (elt result 1))
             (setq renamed (if (> (length result) 3)
                               (elt result 2)
                             nil))
             (setq warning (if (> (length result) 3)
                               (elt result 3)
                             (if (> (length result) 2)
                                 (elt result 2)
                               nil)))
             (if warning
                 (setq has-warning warning)
               nil)
             ;;(update-buffers modified)
             (revert-all-buffers)
             (apply-refac-cmds current-file-name (list 'ok modified)))
            ((and (sequencep (elt result 0)) (equal (elt (elt result 0) 0) 'ok))
             (setq modified (elt (elt result 0) 1))
             (setq name_change (elt result 1))
             (message "Refactoring succeeded %s" modified)
             ;;(update-buffers modified)
             (message "current: %s" current-file-name)
             (revert-all-buffers)
             (apply-refac-cmds current-file-name (list (list 'ok modified) name_change)))
            (t
             (revert-all-buffers)
             (message "Unexpected result: %s" result))
            )
    (cond ((equal (elt result 0) 'ok)
           (setq modified (if (> (length result) 1)
                              (elt result 1)
                            nil))
           (setq renamed (if (> (length result) 3)
                               (elt result 2)
                             nil))
           (setq warning (if (> (length result) 3)
                               (elt result 3)
                             (if (> (length result) 2)
                                 (elt result 2)
                               nil)))
           (if warning
               (setq has-warning warning)
             nil)
           (if (equal modified nil)
               (message "Refactoring finished, and no file has been changed.")
             (preview-commit-cancel current-file-name modified renamed)
             (if (not (eq line-no 0))
               (with-current-buffer (get-file-buffer-1 current-file-name)
                 (goto-line line-no)
                 (goto-column column-no))
               nil)))
          ((equal (elt result 0) 'error)
           (setq rsn (elt result 1))
           (message "Refactoring failed: %S" rsn))
          ((equal (elt result 0) 'badrpc)
           (setq rsn (elt result 1))
           (message "Refactoring failed: %S" rsn))
          ((equal result ['abort])
           (message "Refactoring aborted."))))))



;; redefined get-file-buffer to handle the difference between
;; unix and windows filepath seperator.
(defun get-file-buffer (filename)
 (let ((buffer)
       (bs (buffer-list)))
        (while (and (not buffer) (not (equal bs nil)))
           (let ((b (car bs)))
             (if (and (buffer-file-name b)
                      (and (equal (file-name-nondirectory filename)
                                  (file-name-nondirectory (buffer-file-name b)))
                           (equal (file-name-directory filename)
                            (file-name-directory (buffer-file-name b)))))
                 (setq buffer 'true)
               (setq bs (cdr bs)))))
        (car bs)))


;; (defun get_instances_to_gen(instances buffer highlight-region-overlay)
;;   (setq instances-to-gen nil)
;;   (setq last-position 0)
;;   (while (not (equal instances nil))
;;     (setq new-inst (car instances))
;;     (setq line1 (elt (elt new-inst 0) 0))
;;     (setq col1  (elt (elt  new-inst 0) 1))
;;     (setq line2 (elt (elt new-inst 1) 0))
;;     (setq col2  (elt  (elt new-inst 1) 1))
;;     (if  (> (get-position line1 col1) last-position)
;;      (progn
;;        (highlight-region line1 col1 line2  col2 buffer)
;;        (if (yes-or-no-p "The expression selected occurs more than once in this function clause, would you like to replace the occurrence highlighted too?")
;;            (progn
;;              (setq instances-to-gen (cons new-inst instances-to-gen))
;;              (setq last-position (get-position line2 col2)))
;;          nil))
;;       nil)
;;     (setq instances (cdr instances)))
;;   (org-delete-overlay highlight-region-overlay)
;;   instances-to-gen)


;; (defun erl-refactor-generalisation-composite(args)
;;   "generalise a function definition, used in composite refactoring mode."
;;   (interactive)
;;   (let* ((current-file-name (elt args 0))
;;         (start-end-loc (elt args 3))
;;         (start-line-no (elt (elt start-end-loc 0) 0))
;;         (start-col-no (elt (elt start-end-loc 0) 1))
;;         (end-line-no  (elt (elt start-end-loc 1) 0))
;;         (end-col-no   (elt (elt start-end-loc 1) 1))
;;         (name         (elt args 4))
;;         (search-paths (elt args 5))
;;         (editor       (elt args 6))
;;         (tab-width     (elt args 7)))
;;     (erl-refactor-generalisation-1 current-file-name  start-line-no
;;                                    start-col-no end-line-no end-col-no
;;                                    name search-paths editor tab-width)))


;; (defun erl-refactor-generalisation(name start end)
;;   "Generalise a function definition over an user-selected expression."
;;   (interactive (list (read-string "New parameter name: ")
;;                   (region-beginning)
;;                   (region-end)
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end)))
;;     (if (current-buffer-saved buffer)
;;         (erl-refactor-generalisation-1 current-file-name start-line-no start-col-no end-line-no  end-col-no 
;;                                        name hare-search-paths 'emacs tab-width)
;;       (message "Refactoring aborted."))))

;; (defun erl-refactor-generalisation-1 (current-file-name start-line-no start-col-no end-line-no end-col-no 
;;                                                         name search-paths editor tab-width)
;;   "Generalise a function definition over an user-selected expression."
;;   (setq composite-refac-p (equal editor 'composite_emacs))
;;   (let
;;       ((buffer (get-file-buffer-1 current-file-name)))
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                     (list 'generalise
;;                           (list current-file-name (list start-line-no start-col-no) (list end-line-no end-col-no) name 
;;                                 search-paths  editor tab-width)
;;                           search-paths))
;;       (erl-receive (current-file-name search-paths start-line-no start-col-no buffer highlight-region-overlay editor)
;;           ((['rex ['more_than_one_clause pars]]
;;             (setq  parname (elt pars 0))
;;             (setq funname (elt pars 1))
;;             (setq arity (elt pars 2))
;;             (setq defpos (elt pars 3))
;;             (setq exp (elt pars 4))
;;             (setq side_effect (elt pars 5))
;;             (setq instances_in_fun (elt pars 6))
;;             (setq instances_in_clause (elt pars 7))
;;             (setq logmsg (elt pars 8))
;;             (if (y-or-n-p "The function selected has multiple clauses, would you like to generalise the function clause selected only?")
;;                 (progn
;;                   (with-current-buffer (get-file-buffer-1 current-file-name)
;;                   (setq instances_to_gen (get_instances_to_gen instances_in_clause buffer highlight-region-overlay)))
;;                   (erl-spawn
;;                     (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                                   (list 'refac_gen 'gen_fun_clause
;;                                         (list current-file-name parname funname arity defpos exp tab-width 
;;                                               side_effect instances_to_gen editor logmsg)))
;;                     (erl-receive (start-line-no start-col-no current-file-name)
;;                         ((['rex result]
;;                           (process-result current-file-name result start-line-no start-col-no composite-refac-p))
;;                          ))))
;;            (progn
;;              (with-current-buffer (get-file-buffer-1 current-file-name)
;;                (setq instances_to_gen (get_instances_to_gen instances_in_fun buffer highlight-region-overlay)))
;;              (erl-spawn
;;                (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                                 (list 'refac_gen 'gen_fun_1
;;                                       (list side_effect current-file-name parname 
;;                                             funname arity defpos exp search-paths tab-width 
;;                                             instances_to_gen editor logmsg)))
;;                (erl-receive (start-line-no start-col-no current-file-name)
;;                       ((['rex result]
;;                         (process-result current-file-name result start-line-no start-col-no composite-refac-p))
;;                        ))))))
;;            (['rex ['unknown_side_effect pars]]
;;             (setq  parname (elt pars 0))
;;             (setq funname (elt pars 1))
;;             (setq arity (elt pars 2))
;;             (setq defpos (elt pars 3))
;;             (setq exp (elt pars 4))
;;             (setq no_of_clauses (elt pars 5))
;;             (setq instances_in_fun (elt pars 6))
;;             (setq instances_in_clause (elt pars 7))
;;             (setq logmsg (elt pars 8))
;;             (if (y-or-n-p "Does the expression selected have side effect?")
;;                 (if (> no_of_clauses 1)
;;                     (if (y-or-n-p "The function selected has multiple clauses, would you like to generalise the function clause selected only?")
;;                         (progn
;;                           (with-current-buffer (get-file-buffer-1 current-file-name)
;;                             (setq instances_to_gen (get_instances_to_gen instances_in_clause buffer highlight-region-overlay)))
;;                           (erl-spawn
;;                             (erl-send-rpc wrangler-erl-node 'wrangler_refacs
;;                                           'try_refac (list 'refac_gen 'gen_fun_clause
;;                                                                  (list current-file-name parname funname arity 
;;                                                                        defpos exp tab-width 'true instances_to_gen 
;;                                                                        editor logmsg)))
;;                                 (erl-receive (start-line-no start-col-no current-file-name)
;;                                     ((['rex result]
;;                                       (process-result current-file-name result start-line-no start-col-no composite-refac-p)))
;;                                   )))
;;                       (progn
;;                         (with-current-buffer (get-file-buffer-1 current-file-name)
;;                           (setq instances_to_gen (get_instances_to_gen instances_in_fun buffer highlight-region-overlay)))
;;                         (erl-spawn
;;                           (erl-send-rpc wrangler-erl-node 'wrangler_refacs
;;                                         'try_refac (list 'refac_gen 'gen_fun_1
;;                                                                (list 'true current-file-name parname funname arity 
;;                                                                      defpos exp search-paths tab-width 
;;                                                                      instances_to_gen editor logmsg)))
;;                           (erl-receive (start-line-no start-col-no current-file-name)
;;                               ((['rex result]
;;                                 (process-result current-file-name result start-line-no start-col-no composite-refac-p)))
;;                             ))))
;;                   (progn
;;                     (with-current-buffer (get-file-buffer-1 current-file-name)
;;                       (setq instances_to_gen (get_instances_to_gen instances_in_fun buffer highlight-region-overlay)))
;;                     (erl-spawn
;;                       (erl-send-rpc wrangler-erl-node 'wrangler_refacs
;;                                      'try_refac (list 'refac_gen 'gen_fun_1
;;                                                             (list 'true current-file-name parname funname arity 
;;                                                                   defpos exp search-paths tab-width 
;;                                                                   instances_to_gen editor logmsg)))
;;                       (erl-receive (start-line-no start-col-no current-file-name)
;;                           ((['rex result]
;;                             (process-result current-file-name result start-line-no start-col-no composite-refac-p)))
;;                         )))
;;                   )
;;                (if (> no_of_clauses 1)
;;                    (if (y-or-n-p "The function selected has multiple clauses, would you like to generalise the function clause selected only?")
;;                        (progn
;;                          (with-current-buffer (get-file-buffer-1 current-file-name)
;;                            (setq instances_to_gen (get_instances_to_gen instances_in_clause buffer highlight-region-overlay)))
;;                          (erl-spawn
;;                            (erl-send-rpc wrangler-erl-node 'wrangler_refacs
;;                                          'try_refac (list 'refac_gen 'gen_fun_clause
;;                                                                 (list current-file-name parname funname 
;;                                                                       arity defpos exp tab-width 'false instances_to_gen editor logmsg)))
;;                            (erl-receive (start-line-no start-col-no current-file-name)
;;                                ((['rex result]
;;                                  (process-result current-file-name result start-line-no start-col-no composite-refac-p)))
;;                              )))
;;                         (progn
;;                           (with-current-buffer (get-file-buffer-1 current-file-name)
;;                             (setq instances_to_gen (get_instances_to_gen instances_in_fun buffer highlight-region-overlay)))
;;                           (erl-spawn
;;                             (erl-send-rpc wrangler-erl-node 'wrangler_refacs
;;                                           'try_refac
;;                                           (list 'refac_gen 'gen_fun_1 (list 'false current-file-name parname 
;;                                                                             funname arity defpos exp search-paths 
;;                                                                             tab-width instances_to_gen editor logmsg)))
;;                             (erl-receive (start-line-no start-col-no current-file-name)
;;                                 ((['rex result]
;;                                   (process-result current-file-name result start-line-no start-col-no composite-refac-p)))
;;                               ))))
;;                  (progn
;;                    (with-current-buffer (get-file-buffer-1 current-file-name)
;;                      (setq instances_to_gen (get_instances_to_gen instances_in_fun buffer highlight-region-overlay)))
;;                    (erl-spawn
;;                      (erl-send-rpc wrangler-erl-node 'wrangler_refacs
;;                                    'try_refac (list 'refac_gen 'gen_fun_1
;;                                                           (list 'false current-file-name parname funname arity defpos 
;;                                                                 exp search-paths tab-width instances_to_gen 
;;                                                                 editor logmsg)))
;;                      (erl-receive (start-line-no start-col-no current-file-name)
;;                             ((['rex result]
;;                               (process-result current-file-name result start-line-no start-col-no composite-refac-p)))
;;                        ))))))
;;             (['rex ['multiple_instances pars]]
;;              (setq  parname (elt pars 0))
;;              (setq funname (elt pars 1))
;;              (setq arity (elt pars 2))
;;              (setq defpos (elt pars 3))
;;              (setq exp (elt pars 4))
;;              (setq side_effect (elt pars 5))
;;              (setq instances (elt pars 6))
;;              (setq logmsg (elt pars 7))
;;              (if composite-refac-p
;;                  (erl-spawn
;;                    (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_gen 'gen_fun_1
;;                                                                                            (list side_effect current-file-name parname 
;;                                                                                                  funname arity defpos exp search-paths 
;;                                                                                                  tab-width instances editor logmsg)))
;;                    (erl-receive (start-line-no start-col-no current-file-name)
;;                        ((['rex result]
;;                          (process-result current-file-name result start-line-no start-col-no composite-refac-p)))
;;                      ))
;;                (with-current-buffer (get-file-buffer-1 current-file-name)
;;                  (setq instances_to_gen (get_instances_to_gen instances buffer highlight-region-overlay)))
;;                (erl-spawn
;;                  (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_gen 'gen_fun_1
;;                                                                                          (list side_effect current-file-name parname 
;;                                                                                                funname arity defpos exp search-paths 
;;                                                                                                tab-width instances_to_gen editor logmsg)))
;;                  (erl-receive (start-line-no start-col-no current-file-name)
;;                      ((['rex result]
;;                        (process-result current-file-name result start-line-no start-col-no composite-refac-p)))
;;                    ))))
;;             (['rex result]
;;             ;; (message "refac result %s" result)
;;              (process-result current-file-name result start-line-no start-col-no composite-refac-p))
;;            )))))


;; (defun erl-refactor-fun-extraction(name start end)
;;   "Introduce a new function to represent an user-selected expression/expression sequence."
;;   (interactive (list (read-string "New function name: ")
;;                   (region-beginning)
;;                   (region-end)
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end)))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                         (list 'fun_extraction
;;                               (list current-file-name (list start-line-no start-col-no)
;;                                     (list end-line-no (- end-col-no 1)) name 'emacs tab-width)
;;                               hare-search-paths))
;;        (erl-receive (start-line-no start-col-no end-line-no end-col-no name current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;              (['rex ['warning msg]]
;;          (progn
;;            (if (y-or-n-p msg)
;;                (erl-spawn
;;                  (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'fun_extraction_1 
;;                                (list current-file-name start-line-no start-col-no end-line-no (- end-col-no 1) name 'emacs tab-width))
;;                  (erl-receive (current-file-name)
;;                      ((['rex ['badrpc rsn]]
;;                        (message "Refactoring failed: %S" rsn))
;;                       (['rex ['error rsn]]
;;                        (message "Refactoring failed: %s" rsn))
;;                       (['rex ['ok modified]]
;;                        (preview-commit-cancel current-file-name modified nil)
;;                        ))))
;;              (message "Refactoring aborted.")
;;              )))
;;             (['rex ['ok modified]]
;;              (preview-commit-cancel current-file-name modified nil)
;;              (with-current-buffer (get-file-buffer-1 current-file-name)
;;                (goto-line start-line-no)
;;                (goto-column start-col-no))))))
;;       (message "Refactoring aborted."))))

;; (defun erl-refactor-new-variable(name start end)
;;   "Introduce a new variable to represent a user-selected expression."
;;   (interactive (list (read-string "New variable name: ")
;;                   (region-beginning)
;;                   (region-end)
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end)))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                         (list 'intro_new_var
;;                               (list current-file-name (list start-line-no start-col-no) 
;;                                     (list end-line-no (- end-col-no 1)) name hare-search-paths
;;                                     'emacs tab-width)
;;                               hare-search-paths))
;;           (erl-receive (start-line-no start-col-no end-line-no end-col-no name current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok modified]]
;;              (preview-commit-cancel current-file-name modified nil)
;;              (with-current-buffer (get-file-buffer-1 current-file-name)
;;                (goto-line start-line-no)
;;                (goto-column start-col-no))))))
;;       (message "Refactoring aborted."))))


;; (defun erl-refactor-inline-variable()
;;   "Inline variable definition."
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac
;;                         (list 'inline_var (list current-file-name line-no column-no hare-search-paths 'emacs tab-width)
;;                               hare-search-paths))
;;        (erl-receive (buffer line-no column-no current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok modified]]
;;              (progn
;;                (preview-commit-cancel current-file-name modified nil)
;;                (with-current-buffer (get-file-buffer-1 current-file-name)
;;                  (goto-line line-no)
;;                  (goto-column column-no))))
;;               (['rex ['ok candidates logmsg]]
;;                (with-current-buffer buffer
;;                  (setq candidates-to-unfold (get-candidates-to-unfold candidates buffer))
;;                  (if (equal candidates-to-unfold nil)
;;                      (message "Refactoring finished, and no file has been changed.")
;;                    (erl-spawn
;;                      (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'wrangler_refacs 'inline_var_1(list 
;;                                       current-file-name line-no column-no candidates-to-unfold hare-search-paths 'emacs tab-width logmsg)))
;;                      (erl-receive (current-file-name line-no column-no)
;;                          ((['rex ['badrpc rsn]]
;;                            (message "Refactoring failed: %S" rsn))
;;                           (['rex ['error rsn]]
;;                            (message "Refactoring failed: %s" rsn))
;;                           (['rex ['ok modified]]
;;                            (preview-commit-cancel current-file-name modified nil)
;;                            (with-current-buffer (get-file-buffer-1 current-file-name)
;;                              (goto-line line-no)
;;                              (goto-column column-no)))))))))

;;                )))
;;       (message "Refactoring aborted."))))


;; (defun erl-refactor-new-macro(name start end)
;;   "Introduce a new marco to represent an user-selected syntax phrase."
;;   (interactive (list (read-string "New macro name: ")
;;                   (region-beginning)
;;                   (region-end)
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end)))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                         (list 'new_macro
;;                               (list current-file-name (list start-line-no start-col-no) (list end-line-no (- end-col-no 1))
;;                                     name hare-search-paths 'emacs tab-width)
;;                               hare-search-paths))
;;        (erl-receive (start-line-no start-col-no current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok modified]]
;;              (preview-commit-cancel current-file-name modified nil)
;;              (with-current-buffer (get-file-buffer-1 current-file-name)
;;                (goto-line start-line-no)
;;                (goto-column start-col-no))))))
;;       (message "Refactoring aborted."))))
      
        
;; (defun erl-refactor-fold-against-macro()
;;   "Fold expression(s)/patterns(s) against a macro definition."
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))       
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                     (list 'fold_against_macro
;;                           (list current-file-name line-no column-no hare-search-paths 'emacs tab-width)
;;                           hare-search-paths))
;;       (erl-receive (buffer current-file-name line-no column-no highlight-region-overlay )
;;        ((['rex ['badrpc rsn]]
;;          (message "Refactoring failed: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Refactoring failed: %s" rsn))
;;         (['rex ['ok candidates logmsg]]
;;          (with-current-buffer buffer
;;            (setq candidates-to-fold (get-candidates-to-fold candidates buffer))
;;            (if (equal candidates-to-fold nil)
;;                (message "Refactoring finished, and no file has been changed.")
;;              (erl-spawn
;;                (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac 
;;                                 (list 'refac_fold_against_macro 'fold_against_macro_1
;;                                       (list current-file-name candidates-to-fold hare-search-paths 'emacs tab-width logmsg)))
;;                (erl-receive (current-file-name line-no column-no)
;;                    ((['rex ['badrpc rsn]]
;;                      (message "Refactoring failed: %S" rsn))
;;                     (['rex ['error rsn]]
;;                      (message "Refactoring failed: %s" rsn))
;;                     (['rex ['ok modified]]
;;                      (preview-commit-cancel current-file-name modified nil)
;;                      (with-current-buffer (get-file-buffer-1 current-file-name)
;;                        (goto-line line-no)
;;                        (goto-column column-no))))))))
;;          ))))))
              

;; (defun erl-refactor-fold-expression()
;;   "Fold expression(s) against function definition."
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (if (y-or-n-p 
;;           "Fold expressions against the function clause pointed by cursor (answer 'no' if you would like to input information about the function clause manually)? ")
;;          (fold_expr_by_loc buffer current-file-name line-no column-no)
;;        (erl-refactor-fold-expr-by-name current-file-name (read-string "Module name: ") (read-string "Function name: ") (read-string "Arity: ")
;;                           (read-string "Clause index (starting from 1): ") hare-search-paths 'emacs))
;;       (message "Refactoring aborted."))))
         

;; (defun erl-refactor-fold-expr-by-name-composite(args)
;;   "Fold expression(s) against function definition."
;;   (erl-refactor-fold-expr-by-name (elt args 0) (elt args 1) (elt args 2) (elt args 3)
;;                                   (elt args 4) (elt args 5) (elt args 6)))


;; (defun erl-refactor-fold-expr-by-name(current-file-name module-name function-name arity clause-index search-paths editor)
;;   "Fold expression(s) against function definition."
;;   (setq composite-refac-p (equal editor 'composite_emacs))
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                   (list 'fold_expr_by_name (list current-file-name module-name 
;;                                                 function-name arity clause-index 
;;                                                 search-paths editor tab-width)
;;                         search-paths))
;;     (erl-receive (current-file-name highlight-region-overlay search-paths editor composite-refac-p)
;;      ((['rex ['ok candidates logmsg]]
;;           (let ((buffer (find-file current-file-name)))
;;             (with-current-buffer buffer
;;               (setq candidates-to-fold (get-candidates-to-fold candidates buffer))
;;               (if (equal candidates-to-fold nil)
;;                   (process-result current-file-name (list 'ok nil) 0 0 composite-refac-p)
;;                 (erl-spawn
;;                   (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac 
;;                                 (list 'refac_fold_expression 'do_fold_expression
;;                                       (list  current-file-name candidates-to-fold search-paths editor tab-width logmsg)))
;;                   (erl-receive (current-file-name  composite-refac-p)
;;                       ((['rex result]
;;                         (process-result current-file-name result 0 0 composite-refac-p)))))))))
;;          (['rex result]
;;           (process-result current-file-name result 0 0 composite-refac-p)))
;;       )))
                 
            
;; (defun fold_expr_by_loc(buffer current-file-name line-no column-no)
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                   (list 'fold_expr_by_loc 
;;                         (list current-file-name line-no column-no hare-search-paths 'emacs tab-width)
;;                         hare-search-paths))
;;     (erl-receive (buffer current-file-name line-no column-no highlight-region-overlay)
;;      ((['rex ['badrpc rsn]]
;;        (message "Refactoring failed: %S" rsn))
;;       (['rex ['error rsn]]
;;        (message "Refactoring failed: %s" rsn))
;;       (['rex ['ok candidates logmsg]]
;;        (with-current-buffer buffer
;;          (setq candidates-to-fold (get-candidates-to-fold candidates buffer))
;;          (if (equal candidates-to-fold nil)
;;              (message "Refactoring finished, and no file has been changed.")
;;            (erl-spawn
;;              (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_fold_expression 'do_fold_expression(list 
;;                           current-file-name candidates-to-fold hare-search-paths tab-width logmsg)))
;;              (erl-receive (current-file-name line-no column-no)
;;                  ((['rex ['badrpc rsn]]
;;                    (message "Refactoring failed: %S" rsn))
;;                   (['rex ['error rsn]]
;;                    (message "Refactoring failed: %s" rsn))
;;                   (['rex ['ok modified]]
;;                    (preview-commit-cancel current-file-name modified nil)
;;                    (with-current-buffer (get-file-buffer-1 current-file-name)
;;                      (goto-line line-no)
;;                      (goto-column column-no))))))))
;;        )))))


;; (defun get-candidates-to-fold (candidates buffer) 
;;   (setq candidates-to-fold nil)
;;   (setq last-position 0)
;;   (while (not (equal candidates nil))
;;     (setq new-cand (car candidates))
;;     (setq line1 (elt new-cand 0))
;;     (setq col1  (elt  new-cand 1))
;;     (setq line2 (elt new-cand 2))
;;     (setq col2  (elt  new-cand 3))
;;     (setq funcall (elt new-cand 4))
;;     (setq fundef (elt new-cand 5))
;;     (if  (> (get-position line1 col1) last-position)
;;      (progn 
;;        (highlight-region line1 col1 line2  col2 buffer)
;;        (let ((answer (read-char-spec "Please answer y/n RET to fold/not fold this expression, or Y/N RET to fold all/none of remaining candidates including the one highlighted: "
;;                                      '((?y y "Answer y to fold this candidate expression;")
;;                                        (?n n "Answer n not to fold this candidate expression;")
;;                                        (?Y Y "Answer Y to fold all the remaining candidate expressions;")
;;                                        (?N N "Answer N to fold none of remaining candidate expressions")))))
;;          (cond ((equal answer 'y)
;;                 (setq candidates-to-fold  (cons new-cand candidates-to-fold))
;;                 (setq last-position (get-position line2 col2))
;;                 (setq candidates (cdr candidates)))
;;                ((equal answer 'n)
;;                 (setq candidates (cdr candidates)))
;;                ((equal answer 'Y)
;;                 (setq candidates-to-fold  (append candidates candidates-to-fold))
;;                 (setq candidates nil))
;;                ((equal answer 'N)
;;                 (setq candidates nil)))))
;;       (setq candidates nil)))
;;   (org-delete-overlay highlight-region-overlay)
;;   candidates-to-fold)
              

;; (defun get-candidates-to-unfold (candidates buffer)
;;   (setq candidates-to-unfold nil)
;;   (setq last-position 0)
;;   (while (not (equal candidates nil))
;;     (setq new-cand (car candidates))
;;     (setq line1 (elt (elt new-cand 0) 0))
;;     (setq col1  (elt  (elt new-cand 0)1))
;;     (setq line2 (elt (elt new-cand 1) 0))
;;     (setq col2  (elt  (elt new-cand 1) 1))
;;     (if  (> (get-position line1 col1) last-position)
;;      (progn 
;;        (highlight-region line1 col1 line2  col2 buffer)
;;        (let ((answer (read-char-spec "Please answer y/n RET to unfold/not unfold this variable occurrence, or Y/N RET to unfold all/none of remaining occurrences including the one highlighted: "
;;                                      '((?y y "Answer y to unfold this variable occurrence;")
;;                                        (?n n "Answer n not to unfold this variable occurrence;")
;;                                        (?Y Y "Answer Y to unfold all the remaining occurrences of the variable selected;")
;;                                        (?N N "Answer N to unfold none of remaining occurrences of the variable selected")))))
;;          (cond ((equal answer 'y)
;;                 (setq candidates-to-unfold  (cons new-cand candidates-to-unfold))
;;                 (setq last-position (get-position line2 col2))
;;                 (setq candidates (cdr candidates)))
;;                ((equal answer 'n)
;;                 (setq candidates (cdr candidates)))
;;                ((equal answer 'Y)
;;                 (setq candidates-to-unfold  (append candidates candidates-to-unfold))
;;                 (setq candidates nil))
;;                ((equal answer 'N)
;;                 (setq candidates nil)))))
;;       (setq candidates nil)))
;;   (org-delete-overlay highlight-region-overlay)
;;   candidates-to-unfold)

;; (defun erl-refactor-duplicated-code-in-buffer(mintokens minclones maxpars)
;;   "Find code clones in the current buffer."
;;   (interactive (list (read-string "Minimum number of tokens a code clone should have (default value: 40): ")
;;                   (read-string "Minimum number of appearance times (minimum and default value: 2): ")
;;                   (read-string "Maximum number of parameters of least general common abstraction (default value: 5): ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'duplicated_code_in_buffer
;;                         (list current-file-name mintokens minclones maxpars tab-width))
;;        (erl-receive (buffer current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Duplicated code detection failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Duplicated code detection failed: %s" rsn))
;;             (['rex ['ok result]]
;;              (log-search-result current-file-name result)
;;              (message "Duplicated code detection finished!")))))
;;       (message "Duplicated code detection aborted."))))



;; (defun erl-refactor-duplicated-code-in-dirs(mintokens minclones maxpars)
;;   "Find code clones in the directories specified by the search paths."
;;   (interactive (list (read-string "Minimum number of tokens a code clone should have (default value: 40): ")
;;                   (read-string "Minimum number of appearance times (minimum and default value: 2): ")
;;                   (read-string "Maximum number of parameters of least general common abstraction (default value: 5): ")  
;;                   ))
;;   (if (y-or-n-p (format "Find duplicated code in the following directories: %s" hare-search-paths))
;;       (let ((current-file-name (buffer-file-name))
;;          (buffer (current-buffer)))
;;      (if (buffers-saved)
;;          (erl-spawn
;;            (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac_1 (list 'duplicated_code_in_dirs
;;                          (list hare-search-paths mintokens minclones maxpars tab-width)
;;                             hare-search-paths))
;;            (erl-receive (buffer)
;;                ((['rex ['badrpc rsn]]
;;                  (message "Duplicated code detection failed: %S" rsn))
;;                 (['rex ['error rsn]]
;;                  (message "Duplicated code detection failed: %s" rsn))
;;                 (['rex ['ok result]]
;;                  (log-search-result current-file-name result)
;;                  (message "Duplicated code detection finished.")))))
;;        (message "Duplicated code detection aborted.")
;;        ))
;;     (message "Please customize Wrangler SearchPaths to check duplicated code in other directories.")
;;     ))
                   
  
;; (defun erl-refactor-inc-sim-code-detection-in-buffer(minlen mintoks minfreq maxvars simiscore)
;;   "Similar code detection in buffer."
;;  (interactive (list (read-string "Minimum length of an expression sequence (default value: 5): ")
;;                  (read-string "Minimum number of tokens a code clone should have (default value: 40): ")
;;                  (read-string "Minimum number of appearance times (minimum and default value: 2): ")
;;                  (read-string "Maximum number of new parameters of the least-general common abstraction (default value: 4): ")
;;                  (read-string "Please input a similarity score between 0.1 and 1.0 (default value: 0.8):")
;;                  ))
;;    (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;    (remove-highlights)
;;    (if (current-buffer-saved buffer)
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_inc_sim_code 'inc_sim_code_detection_in_buffer
;;                         (list current-file-name minlen mintoks minfreq maxvars simiscore hare-search-paths tab-width)))
;;       (erl-receive (buffer current-file-name)
;;           ((['rex ['badrpc rsn]]
;;             (message "Searching failed: %S" rsn))
;;            (['rex ['error rsn]]
;;             (message "Searching failed: %s" rsn))
;;            (['rex ['ok result]]
;;             (log-search-result current-file-name result)
;;             (message "Similar code detection finished.")
;;             ))))
;;        (message "Similar code detection aborted.")
;;        )))

;; (defun erl-refactor-inc-sim-code-detection-in-dirs(minlen mintoks minfreq maxvars simiscore)
;;   "Similar code detection in dirs."
;;  (interactive (list (read-string "Minimum length of an expression sequence (default value: 5): ")
;;                  (read-string "Minimum number of tokens a code clone should have (default value: 40): ")
;;                  (read-string "Minimum number of appearance times (minimum and default value: 2): ")
;;                  (read-string "Maximum number of new parameters of the least-general common abstraction (default value: 4): ")
;;                  (read-string "Please input a similarity score between 0.1 and 1.0 (default value: 0.8):")
;;                  ))
;;  (if (y-or-n-p (format "Find similar code in the following directories: %s" hare-search-paths))
;;      (let ((current-file-name (buffer-file-name))
;;         (buffer (current-buffer)))
;;        (if (buffers-saved)
;;         (erl-spawn
;;           (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_inc_sim_code 'inc_sim_code_detection
;;                         (list hare-search-paths minlen mintoks minfreq maxvars simiscore hare-search-paths tab-width)))
;;           (erl-receive (buffer current-file-name)
;;               ((['rex ['badrpc rsn]]
;;                 (message "Similar code detection failed: %S" rsn))
;;                (['rex ['error rsn]]
;;                 (message "Similar code detection failed: %s" rsn))
;;                (['rex ['ok result]]
;;                 (log-search-result current-file-name result)
;;                 (message "Similar code detection finished."))))
;;           )
;;       (message "Similar code detection aborted.")
;;       ))
;;      (message "Please customize Wrangler Search Paths to check similar code in other directories.")
;;     ))

;; (defun erl-refactor-sim-code-detection-in-dirs(minlen minfreq simiscore)
;;   "Similar code detection in dirs."
;;  (interactive (list (read-string "Minimum length of an expression sequence (default value: 5): ")
;;                  (read-string "Minimum number of appearance times (minimum and default value: 2): ")
;;                  (read-string "Please input a similarity score between 0.1 and 1.0 (default value: 0.8):")
;;                  ))
;;  (if (y-or-n-p (format "Find similar code in the following directories: %s" hare-search-paths))
;;      (let ((current-file-name (buffer-file-name))
;;         (buffer (current-buffer)))
;;        (if (buffers-saved)
;;         (erl-spawn
;;           (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_sim_code 'sim_code_detection
;;                         (list hare-search-paths minlen minfreq simiscore hare-search-paths tab-width)))
;;           (erl-receive (buffer current-file-name)
;;               ((['rex ['badrpc rsn]]
;;                 (message "Similar code detection failed: %S" rsn))
;;                (['rex ['error rsn]]
;;                 (message "Similar code detection failed: %s" rsn))
;;                (['rex ['ok result]]
;;                 (log-search-result current-file-name result)
;;                 (message "Similar code detection finished.")))))
;;       (message "Similar code detection aborted.")
;;       ))
;;      (message "Please customize Wrangler Search Paths to check similar code in other directories.")
;;     ))

                   
  
;; (defun erl-refactor-sim-code-detection-in-buffer(minlen minfreq simiscore)
;;   "Similar code detection in the current buffer."
;;  (interactive (list (read-string "Minimum length of an expression sequence (default value: 5): ")
;;                  (read-string "Minimum number of appearance times (minimum and default value: 2): ")
;;                  (read-string "Please input a similarity score between 0.1 and 1.0 (default value: 0.8):")
;;                  ))
;;  (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;    (remove-highlights)
;;    (if (current-buffer-saved buffer)
;;        (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_sim_code 'sim_code_detection_in_buffer
;;                                  (list current-file-name minlen minfreq simiscore  hare-search-paths tab-width)))
;;       (erl-receive (buffer current-file-name)
;;           ((['rex ['badrpc rsn]]
;;             (message "Searching failed: %S" rsn))
;;            (['rex ['error rsn]]
;;             (message "Searching failed: %s" rsn))
;;            (['rex ['ok result]]
;;             (log-search-result current-file-name result)
;;             (message "Similar code detection finished.")
;;             ))))
;;        (message "Similar code detection aborted.")
;;        )))
 


;; (defun erl-refactor-similar-expression-search(similarity-score start end)
;;   "Search expressions that are similar to an user-selected expression or expression sequence in the current buffer."
;;   (interactive (list (read-string "Please input a similarity score between 0.1 and 1.0 (default value: 0.8):")
;;              (region-beginning)
;;              (region-end)
;;              ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end)))
;;     (remove-highlights)
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'similar_expression_search_in_buffer
;;                      (list current-file-name (list start-line-no start-col-no) (list  end-line-no end-col-no) 
;;                               similarity-score hare-search-paths tab-width))
;;        (erl-receive (buffer)
;;            ((['rex ['badrpc rsn]]
;;              (message "Searching failed: %S" rsn))
;;             (['rex ['error rsn]]
;;          (message "Searching failed: %s" rsn))
;;             (['rex ['ok regions]]
;;              (with-current-buffer buffer 
;;                (highlight-instances-1 regions (car regions) buffer)
;;                (message "Searching finished; use 'C-c C-w e' to remove highlights.\n")
;;                )))))
;;       (message "Refactoring aborted."))))



;; (defun erl-refactor-similar-expression-search-in-dirs(similarity-score start end)
;;   "Search expressions that are similar to an user-selected expression or expression sequence in the current buffer."
;;   (interactive (list (read-string "Please input a similarity score between 0.1 and 1.0 (default value: 0.8):")
;;              (region-beginning)
;;              (region-end)
;;              ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end)))
;;     (remove-highlights)
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'similar_expression_search_in_dirs
;;                      (list current-file-name (list start-line-no start-col-no) 
;;                               (list end-line-no end-col-no) similarity-score hare-search-paths tab-width))
;;        (erl-receive (buffer)
;;            ((['rex ['badrpc rsn]]
;;              (message "Searching failed: %S" rsn))
;;             (['rex ['error rsn]]
;;          (message "Searching failed: %s" rsn))
;;             (['rex ['ok regions]]
;;              (with-current-buffer buffer 
;;                (highlight-instances-1 regions (car regions) buffer)
;;                (message "Searching finished; use 'C-c C-w e' to remove highlights.\n")
;;                )))))
;;       (message "Refactoring aborted."))))

;; (defun erl-refactor-fun-to-process (name)
;;   "From a function to a process."
;;   (interactive (list (read-string "Process name: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))       
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                     (list 'fun_to_process (list current-file-name line-no column-no name hare-search-paths 'emacs tab-width)
;;                           hare-search-paths))
;;       (erl-receive (current-file-name line-no column-no name)
;;        ((['rex ['badrpc rsn]]
;;          (message "Refactoring failed: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Refactoring failed: %s" rsn))
;;         (['rex ['undecidables msg logmsg]]
;;           (if (y-or-n-p "Do you still want to continue the refactoring?")
;;               (erl-spawn
;;                 (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_fun_to_process 'fun_to_process_1
;;                               (list current-file-name line-no column-no  name hare-search-paths tab-width 'emacs logmsg)))
;;                 (erl-receive (line-no column-no current-file-name)
;;                     ((['rex ['badrpc rsn]]
;;                       (message "Refactoring failed: %S" rsn))
;;                      (['rex ['error rsn]]
;;                       (message "Refactoring failed: %s" rsn))
;;                      (['rex ['ok modified]]
;;                       (preview-commit-cancel current-file-name modified nil)
;;                       (with-current-buffer (get-file-buffer-1 current-file-name)
;;                         (goto-line line-no)
;;                         (goto-column column-no)))))))
;;           (message "Refactoring aborted!"))
;;         (['rex ['ok modified]]
;;          (progn
;;            (preview-commit-cancel current-file-name modified nil)
;;            (with-current-buffer (get-file-buffer-1 current-file-name)
;;              (goto-line line-no)
;;              (goto-column column-no))))
;;       )))))


(defun current-line-no ()
  "grmpff. does anyone understand count-lines?"
  (+ (if (equal 0 (current-column)) 1 0)
     (count-lines (point-min) (point)))
  )

(defun current-column-no ()
  "the column number of the cursor"
  (+ 1 (current-column)))


(defun line-no-pos (pos)
  "grmpff. why no parameter to current-column?"
  (save-excursion
    (goto-char pos)
    (+ (if (equal 0 (current-column)) 1 0)
       (count-lines (point-min) (point))))
  )

(defun current-column-pos (pos)
  "grmpff. why no parameter to current-column?"
  (save-excursion
    (goto-char pos) (+ 1 (current-column)))
  )


(defun get-position(line col)
  "get the position at lie (line, col)"
  (save-excursion
    (goto-line line)
    (move-to-column col)
    (- (point) 1)))


(defun goto-column(col)
  (if (> col 0)
      (move-to-column (- col 1))
    (move-to-column col)))
                      

(defvar highlight-region-overlay
  ;; Dummy initialisation
  (cond (erlang-xemacs-p
         (make-extent 1 1))
        (t (make-overlay 1 1)))
  "Overlay for highlighting.")

(defface highlight-region-face
  '((t (:background "CornflowerBlue")))
    "Face used to highlight current line.")

(defface def-instance-face
   '((t (:background "Orange")))
    "Face used to highlight def instance.")

(defface use-instance-face
   '((t (:background "CornflowerBlue")))
    "Face used to highlight def instance.")


(defun highlight-region(line1 col1 line2 col2 buffer)
  "hightlight the specified region"
  (org-overlay-put highlight-region-overlay
               'face 'highlight-region-face)
  (org-move-overlay highlight-region-overlay (get-position line1 col1)
                    (get-position line2 (+ 1 col2)) buffer)
  (goto-line line2)
  (goto-column col2)
  )

;; (defun erl-refactor-add-a-tag (name)
;;   "Add a tag to the messages received by a process."
;;   (interactive (list (read-string "Tag to add: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))       
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                     (list 'add_a_tag (list current-file-name line-no column-no name hare-search-paths 'emacs tab-width)
;;                           hare-search-paths))
;;       (erl-receive (name current-file-name line-no column-no)
;;        ((['rex ['badrpc rsn]]
;;          (message "Refactoring failed: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Refactoring failed: %s" rsn))
;;         (['rex ['ok modified]]
;;          (progn
;;            (preview-commit-cancel current-file-name modified nil)
;;            (with-current-buffer (get-file-buffer-1 current-file-name)
;;              (goto-line line-no)
;;              (goto-column column-no)))))))))
           

;; (defun erl-refactor-add-a-tag-1 (name)
;;   "Add a tag to the messages received by a process."
;;   (interactive (list (read-string "Tag to add: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))       
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'add_a_tag(list current-file-name line-no column-no name hare-search-paths tab-width))
;;       (erl-receive (buffer name current-file-name)
;;        ((['rex ['badrpc rsn]]
;;          (message "Refactoring failed: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Refactoring failed: %s" rsn))
;;         (['rex ['ok candidates]]
;;          (with-current-buffer buffer (revert-buffer nil t t) 
;;            (while (not (equal candidates nil))
;;              (setq send (car candidates))
;;              (setq mod (elt send 0))
;;              (setq fun (elt send 1))
;;              (setq arity (elt send 2))
;;              (setq index (elt send 3))
;;              (erl-spawn
;;                (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_add_a_tag 'send_expr_to_region(list 
;;                                                                                              current-file-name mod fun arity index tab-width)))
;;                (erl-receive (buffer current-file-name name)
;;                    ((['rex ['badrpc rsn]]
;;                      ;;  (setq candidates nil)
;;                      (message "Refactoring failed: %s" rsn))                                   
;;                     (['rex ['error rsn]]
;;                      ;;  (setq candidates nil)
;;                      (message "Refactoring failed: %s" rsn))
;;                     (['rex ['ok region]]
;;                      (with-current-buffer buffer 
;;                      (progn (setq line1 (elt region 0))
;;                             (setq col1 (elt region 1))
;;                             (setq line2 (elt region 2))
;;                             (setq col2 (elt region 3))
;;                             (highlight-region line1 col1 line2  col2 buffer)
;;                             (if (y-or-n-p "Should a tag be added to this expression? ")
;;                                 (erl-spawn (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac (list 'refac_add_a_tag 'add_a_tag(list 
;;                                                  current-file-name name line1 col1 line2 col2 tab-width)))
;;                                   (erl-receive (buffer)
;;                                       ((['rex ['badrpc rsn]]
;;                                         (message "Refactoring failed: %s" rsn))
;;                                        (['rex ['error rsn]]
;;                                         (message "Refactoring failed: %s" rsn))
;;                                        (['rex ['ok res]]
;;                                         (with-current-buffer buffer (revert-buffer nil t t)
;;                                              (org-delete-overlay highlight-region-overlay))
;;                                        ))))
;;                              (delete-overlay highlight-region-overlay)
;;                             )))))))
;;              (setq candidates (cdr candidates)))
;;            (with-current-buffer buffer (revert-buffer nil t t))
;;            ;; (delete-overlay highlight-region-overlay)
;;            (message "Refactoring succeeded!"))))))))
 
;; (defun erl-refactor-tuple-funpar (start end)
;;   "Tuple function argument."
;;   (interactive (list (region-beginning)
;;                   (region-end)
;;                   ))
;;   (let((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end))) 
;;     (if (buffers-saved)
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                     (list 'tuple_funpar 
;;                           (list current-file-name (list start-line-no start-col-no)
;;                                 (list end-line-no end-col-no) 
;;                                 hare-search-paths 'emacs tab-width)
;;                           hare-search-paths))
;;       (erl-receive (start-line-no start-col-no end-line-no end-col-no current-file-name)
;;        ((['rex ['badrpc rsn]]
;;          (message "Refactoring failed: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Refactoring failed: %s" rsn))
;;         (['rex ['warning msg]]
;;          (progn
;;            (if (y-or-n-p msg)
;;                (erl-spawn
;;                  (erl-send-rpc wrangler-erl-node 'wrangler_refacs  'tuple_funpar_1
;;                                         (list current-file-name (list start-line-no start-col-no) 
;;                                               (list end-line-no end-col-no)
;;                                               hare-search-paths 'emacs tab-width))
;;                  (erl-receive (start-line-no start-col-no current-file-name)
;;                      ((['rex ['badrpc rsn]]
;;                        (message "Refactoring failed: %S" rsn))
;;                       (['rex ['error rsn]]
;;                        (message "Refactoring failed: %s" rsn))
;;                       (['rex ['ok modified]]
;;                        (progn
;;                          (preview-commit-cancel current-file-name modified nil)
;;                          (with-current-buffer (get-file-buffer-1 current-file-name)
;;                            (goto-line start-line-no)
;;                            (goto-column start-col-no)))))))
;;              (message "Refactoring aborted.")
;;              )))
;;         (['rex ['ok modified]]
;;          (progn
;;            (preview-commit-cancel current-file-name modified nil)
;;            (with-current-buffer (get-file-buffer-1 current-file-name)
;;              (goto-line start-line-no)
;;              (goto-column start-col-no))))
;;         )))
;;     (message "Refactoring aborted."))))
            


;; (defun erl-refactor-normalise-record-expr ()
;;   "Normalise a record expression."
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (current-buffer-saved buffer)
;;      (if (y-or-n-p "Show record fields with default values?")            
;;          (erl-spawn
;;            (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                             (list 'normalise_record_expr 
;;                                   (list current-file-name line-no column-no 'true hare-search-paths 'emacs tab-width)
;;                                   hare-search-paths))
;;            (erl-receive (line-no column-no current-file-name)
;;                ((['rex ['badrpc rsn]]
;;                  (message "Refactoring failed: %S" rsn))
;;                 (['rex ['error rsn]]
;;                  (message "Refactoring failed: %s" rsn))
;;                 (['rex ['ok modified]]
;;                  (progn
;;                    (if (equal modified nil)
;;                        (message "Refactoring finished, and no file has been changed.")
;;                      (preview-commit-cancel current-file-name modified nil))
;;                    (with-current-buffer (get-file-buffer-1 current-file-name)
;;                      (goto-line line-no)
;;                      (goto-column column-no))))
;;                 )))
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                           (list 'normalise_record_expr 
;;                                 (list current-file-name line-no column-no 'false hare-search-paths 'emacs tab-width)
;;                                 hare-search-paths))                          
;;          (erl-receive (line-no column-no current-file-name)
;;              ((['rex ['badrpc rsn]]
;;                (message "Refactoring failed: %S" rsn))
;;                 (['rex ['error rsn]]
;;                  (message "Refactoring failed: %s" rsn))
;;                 (['rex ['ok modified]]
;;                  (progn
;;                    (if (equal modified nil)
;;                        (message "Refactoring finished, and no file has been changed.")
;;                      (preview-commit-cancel current-file-name modified nil))
;;                    (with-current-buffer (get-file-buffer-1 current-file-name)
;;                      (goto-line line-no)
;;                      (goto-column column-no))))
;;                 ))))
;;       (message "Refactoring aborted.")
;;       )))
                  


;; (defun erl-refactor-introduce-let(name start end)
;;   "Introduce dependence between quickcheck generators."
;;   (interactive (list (read-string "Pattern variable name: ")
;;                   (region-beginning)
;;                   (region-end)
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;      (start-line-no (line-no-pos start))
;;      (start-col-no  (current-column-pos start))
;;      (end-line-no   (line-no-pos end))
;;      (end-col-no    (current-column-pos end)))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                         (list 'new_let (list current-file-name (list start-line-no start-col-no)
;;                                              (list end-line-no (- end-col-no 1))
;;                                              name hare-search-paths 'emacs tab-width)
;;                               hare-search-paths))
;;        (erl-receive (start-line-no start-col-no current-file-name name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['question msg expr parent-expr cmd]]
;;              (progn
;;                (if (y-or-n-p msg)
;;                    (erl-spawn
;;                      (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac
;;                                       (list 'refac_new_let 'new_let_1
;;                                             (list current-file-name name expr parent-expr hare-search-paths 'emacs tab-width cmd)))
;;                      (erl-receive (current-file-name)
;;                          ((['rex ['badrpc rsn]]
;;                            (message "Refactoring failed: %S" rsn))
;;                           (['rex ['error rsn]]
;;                            (message "Refactoring failed: %s" rsn))
;;                           (['rex ['ok modified]]
;;                            (preview-commit-cancel current-file-name modified nil)
;;                            ))))
;;                  (message "Refactoring failed: the expression selected is not a QuickCheck generator.")
;;                  )))         
;;             (['rex ['ok modified]]
;;              (preview-commit-cancel current-file-name modified nil)
;;              (with-current-buffer (get-file-buffer-1 current-file-name)
;;                (goto-line start-line-no)
;;                (goto-column start-col-no))))))
;;       (message "Refactoring aborted."))))


;; (defun erl-refactor-merge-let()
;;   "Merge undependent ?LET applications."
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))       
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac (list 'merge_let
;;                  (list current-file-name hare-search-paths 'emacs tab-width)
;;                     hare-search-paths))
;;       (erl-receive (buffer current-file-name highlight-region-overlay )
;;        ((['rex ['badrpc rsn]]
;;          (message "Refactoring failed: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Refactoring failed: %s" rsn))
;;         (['rex ['not_found msg]]
;;          (message "%s" msg))
;;         (['rex ['ok candidates logmsg]]
;;          (with-current-buffer buffer
;;            (setq candidates-to-fold (get-candidates-to-merge candidates buffer))
;;            (if (equal candidates-to-fold nil)
;;                (message "Refactoring finished, and nothing has been changed.")
;;              (erl-spawn
;;                (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'merge_let_1 (list 
;;                                       current-file-name candidates-to-fold hare-search-paths 'emacs tab-width logmsg))
;;                (erl-receive (current-file-name)
;;                    ((['rex ['badrpc rsn]]
;;                      (message "Refactoring failed: %S" rsn))
;;                     (['rex ['error rsn]]
;;                      (message "Refactoring failed: %s" rsn))
;;                     (['rex ['ok modified]]
;;                      (preview-commit-cancel current-file-name modified nil)
;;                      ))))))
;;          ))))))
              
      

;; (defun erl-refactor-merge-forall()
;;   "Merge undependent ?FORALL applications."
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))       
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                     (list 'merge_forall
;;                           (list current-file-name hare-search-paths 'emacs tab-width)
;;                           hare-search-paths))
;;       (erl-receive (buffer current-file-name highlight-region-overlay )
;;        ((['rex ['badrpc rsn]]
;;          (message "Refactoring failed: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Refactoring failed: %s" rsn))
;;         (['rex ['not_found msg]]
;;          (message "%s" msg))
;;         (['rex ['ok candidates logmsg]]
;;          (with-current-buffer buffer
;;            (setq candidates-to-fold (get-candidates-to-merge candidates buffer))
;;               (if (equal candidates-to-fold nil)
;;                (message "Refactoring finished, and nothing has been changed.")
;;              (erl-spawn
;;                (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'merge_forall_1 (list 
;;                                       current-file-name candidates-to-fold hare-search-paths 'emacs tab-width logmsg))
;;                (erl-receive (current-file-name)
;;                    ((['rex ['badrpc rsn]]
;;                      (message "Refactoring failed: %S" rsn))
;;                     (['rex ['error rsn]]
;;                      (message "Refactoring failed: %s" rsn))
;;                     (['rex ['ok modified]]
;;                      (preview-commit-cancel current-file-name modified nil)
;;                      ))))))
;;          ))))))

;; (defun get-candidates-to-merge (candidates buffer)
;;   (setq candidates-to-merge nil)
;;   (setq last-position 0)
;;   (while (not (equal candidates nil))
;;     (setq new-cand (car candidates))
;;     (setq loc (elt new-cand 0))
;;     (setq line1 (elt loc 0))
;;     (setq col1  (elt  loc 1))
;;     (setq line2 (elt loc 2))
;;     (setq col2  (elt  loc 3))
;;     (setq newletapp (elt new-cand 1))
;;     (if  (> (get-position line1 col1) last-position)
;;      (progn 
;;        (highlight-region line1 col1 line2  col2 buffer)
;;        (let ((answer (read-char-spec "Please answer y/n RET to merge/not merge this expression, or Y/N RET to merge all/none of remaining candidates including the one highlighted: "
;;                                      '((?y y "Answer y to merge this candidate expression;")
;;                                        (?n n "Answer n not to merge this candidate expression;")
;;                                        (?Y Y "Answer Y to merge all the remaining candidate expressions;")
;;                                        (?N N "Answer N to merge none of remaining candidate expressions")))))
;;          (cond ((equal answer 'y)
;;                 (setq candidates-to-merge  (cons new-cand candidates-to-merge))
;;                 (setq last-position (get-position line2 col2))
;;                 (setq candidates (cdr candidates)))
;;                ((equal answer 'n)
;;                 (setq candidates (cdr candidates)))
;;                ((equal answer 'Y)
;;                 (setq candidates-to-merge  (append candidates candidates-to-merge))
;;                 (setq candidates nil))
;;                ((equal answer 'N)
;;                 (setq candidates nil)))))
;;       (setq candidates nil)))
;;   (org-delete-overlay highlight-region-overlay)
;;   candidates-to-merge)

;; (defun erl-refactor-eqc-statem-to-record()
;;    "Turn a non-record eqc-statem state to a recrod."
;;    (interactive) 
;;    (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;      (if (current-buffer-saved buffer)
;;       (erl-spawn
;;         (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                          (list 'eqc_statem_to_record (list current-file-name hare-search-paths 'emacs tab-width)
;;                                hare-search-paths))
;;         (erl-receive (current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok ['tuple no-of-fields] state-funs ]]
;;              (erl-refactor-state-to-record-1 current-file-name no-of-fields state-funs 'true 'eqc_statem_to_record_1))
;;             (['rex ['ok non-tuple state-funs]]
;;              (if (yes-or-no-p "The current type of the state is not tuple; create a record with a single field?")
;;                  (erl-refactor-state-to-record-1 current-file-name 1 state-funs 'false 'eqc_statem_to_record_1)
;;                (message "Refactoring aborted.")))                  
;;             )))
;;        (message "Refactoring aborted."))))


;; (defun erl-refactor-eqc-fsm-to-record()
;;   "Turn a non-record eqc-fsm state to a recrod."
;;   (interactive) 
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;     (if (current-buffer-saved buffer)
;;         (erl-spawn
;;         (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                          (list 'eqc_fsm_to_record (list current-file-name hare-search-paths 'emacs tab-width)
;;                                hare-search-paths))
;;         (erl-receive (current-file-name)
;;                ((['rex ['badrpc rsn]]
;;                  (message "Refactoring failed: %S" rsn))
;;                 (['rex ['error rsn]]
;;                  (message "Refactoring failed: %s" rsn))
;;                 (['rex ['ok ['tuple no-of-fields] state-funs]]
;;                  (erl-refactor-state-to-record-1 current-file-name no-of-fields state-funs 'true 'eqc_fsm_to_record_1))
;;                 (['rex ['ok non-tuple state-funs]]
;;              (if (yes-or-no-p "The current type of the state is not tuple; create a record with a single field?")
;;                  (erl-refactor-state-to-record-1 current-file-name 1 state-funs 'false 'eqc_fsm_to_record_1)
;;                (message "Refactoring aborted.")))                  
;;                 )))
;;        (message "Refactoring aborted."))))


;; (defun erl-refactor-gen-fsm-to-record()
;;    "Turn a non-record gen-fsm state to a recrod."
;;    (interactive) 
;;    (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;      (if (current-buffer-saved buffer)
;;       (erl-spawn 
;;         (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                          (list 'gen_fsm_to_record (list current-file-name hare-search-paths 'emacs tab-width)
;;                                hare-search-paths))
;;         (erl-receive (current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok ['tuple no-of-fields] state-funs]]
;;              (erl-refactor-state-to-record-1 current-file-name no-of-fields state-funs 'true 'gen_fsm_to_record_1))
;;             (['rex ['ok non-tuple state-funs]]
;;              (if (yes-or-no-p "The current type of the state is not tuple; create a record with a single field?")
;;                  (erl-refactor-state-to-record-1 current-file-name 1 state-funs 'false 'gen_fsm_to_record_1)
;;                (message "Refactoring aborted.")))                  
;;             )))
;;        (message "Refactoring aborted."))))

;; (defun erl-refactor-state-to-record-1(current-file-name no-of-fields state-funs is-tuple function-name)
;;   "Turn a non-record state to a record."
;;   (interactive)
;;   (setq num 1)
;;   (setq field-names nil)
;;   (let ((record-name (read-string "Record name: "))
;;      (buffer (get-file-buffer-1 current-file-name)))    
;;     (while (not (> num no-of-fields))
;;       (let ((str (format "Field name %d of %d : " num no-of-fields)))
;;      (setq field-names (cons (read-string str) field-names))
;;      (setq num (+ num 1))))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'wrangler_refacs function-name 
;;                      (list current-file-name record-name (reverse field-names) state-funs is-tuple hare-search-paths 'emacs tab-width))
;;        (erl-receive (current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok modified]]
;;              (preview-commit-cancel current-file-name modified nil)
;;             ))))
;;        (message "Refactoring aborted."))))


;; (defun erl-refactor-statem-to-fsm (name)
;;   "From eqc_statem to eqc_fsm."
;;   (interactive (list (read-string "Initial state name: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;     (if (current-buffer-saved buffer)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                         (list 'eqc_statem_to_fsm (list current-file-name name hare-search-paths 'emacs tab-width)
;;                               hare-search-paths))
;;        (erl-receive (current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok modified]]
;;              (progn
;;                (if (equal modified nil)
;;                    (message "Refactoring finished, and no file has been changed.")
;;                  (preview-commit-cancel current-file-name modified nil)
;;                  )))))
;;       (message "Refactoring aborted.")))))


;; (defun erl-refactor-test-cases-to-property()
;;   "Create a oneof QuickCheck generator."
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'refac_qc_gen 'test_cases_to_property (list current-file-name line-no column-no hare-search-paths tab-width))
;;        (erl-receive (line-no column-no current-file-name)
;;            ((['rex ['badrpc rsn]]
;;              (message "Refactoring failed: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Refactoring failed: %s" rsn))
;;             (['rex ['ok modified warning]]
;;              (progn
;;                (setq has-warning warning)
;;                (preview-commit-cancel current-file-name modified nil)
;;                (with-current-buffer (get-file-buffer-1 current-file-name)
;;                  (goto-line line-no)
;;                  (goto-column column-no))))
;;             )))
;;       (message "Refactoring aborted."))))
         
              

;; (defun erl-refactor-bug-precond()
;;   "Remove bug preconditions."           
;;   (interactive)                 
;;   (apply-adhoc-refac 'refac_bug_cond))


;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;;                                                                    %%
;;  Code Inspector                                                    %%
;;                                                                    %%
;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
;; (defun erl-wrangler-code-inspector-var-instances()
;;   "Sematic search of instances of a variable"
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (remove-highlights)
;;     (save-buffer)
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'inspec_lib 'find_var_instances 
;;                        (list current-file-name line-no column-no hare-search-paths tab-width))
;;       (erl-receive (buffer)
;;        ((['rex ['badrpc rsn]]
;;          (message "Error: %S" rsn))
;;         (['rex ['error rsn]]
;;          (message "Error: %s" rsn))
;;         (['rex ['ok regions defpos]]
;;          (with-current-buffer buffer (highlight-instances regions defpos buffer)
;;                               (message "\nUse 'C-c C-w e' to remove highlights.\n")
;;                               )
                                                
;;          ))))))

(defun remove-highlights()
  "remove highligths in the buffer"
  (interactive)
  (dolist (ov (if (featurep 'xemacs)
                  (extent-list (current-buffer))
                (overlays-in  1 100000)))
    (if (equal ov highlight-region-overlay)
        nil
      (org-delete-overlay ov))))


(defun highlight-instances-with-same-face(filename regions)
  "highlight regions in the buffer with the same color"
  ; (setq buffer (find-file filename))
  (let (buffer (find-file filename))
  (with-current-buffer buffer
    (dolist (r regions)
      (highlight-use-instance r buffer)))))


(defun highlight-a-instance(region buffer)
   "highlight one region in the buffer"
   (let ((line1 (elt (elt region 0) 0))
          (col1 (elt (elt region 0) 1))
          (line2 (elt (elt region 1) 0))
          (col2 (elt (elt region 1) 1)))
     (goto-char (get-position line1 (- col1 1)))
     (highlight-region line1 col1 line2 col2 buffer)
       ))
    
(defun highlight-instances(regions defpos buffer)
  "highlight regions in the buffer"
  (dolist (r regions)
     (if (member (elt r 0) defpos)
         (highlight-def-instance r buffer)
       (highlight-use-instance r buffer))))


(defun highlight-instances-1(regions selected buffer)
  "highlight regions in the buffer"
  (dolist (r regions)
    (if (equal r selected)
        (highlight-def-instance (elt r 1) buffer)
      (highlight-use-instance (elt r 1) buffer))))

(defun highlight-def-instance(region buffer)
   "highlight one region in the buffer"
   (let ((line1 (elt (elt region 0) 0))
          (col1 (elt (elt region 0) 1))
          (line2 (elt (elt region 1) 0))
          (col2 (elt (elt region 1) 1)))
     (highlight-region-with-face line1 col1 line2 col2 buffer 'def-instance-face)))
    

(defun highlight-use-instance(region buffer)
   "highlight one region in the buffer"
   (let ((line1 (elt (elt region 0) 0))
          (col1 (elt (elt region 0) 1))
          (line2 (elt (elt region 1) 0))
          (col2 (elt (elt region 1) 1)))
     (highlight-region-with-face line1 col1 line2 col2 buffer 'use-instance-face)))
       

 
 

(defun highlight-region-with-face(line1 col1 line2 col2 buffer face)
  "hightlight the specified region"
  (org-overlay-put (org-make-overlay (get-position line1 col1) (get-position line2 (+ 1 col2)))
                   'face face))
  

(defun org-make-overlay(beg end)
   ;; make a overlay
   (if (featurep 'xemacs)
       (make-extent beg end)
     (make-overlay beg end)))

(defun org-move-overlay (ovl beg end &optional buffer)
  (if (featurep 'xemacs)
      (set-extent-endpoints ovl beg end (or buffer (current-buffer)))   
    (move-overlay ovl beg end buffer)))

(defun org-overlay-put (ovl prop value)
  (if (featurep 'xemacs)
      (set-extent-property  ovl prop value)
    (overlay-put ovl prop value)))

(defun org-delete-overlay (ovl)
  (if (featurep 'xemacs) (progn (detach-extent ovl) nil) (delete-overlay ovl)))


;; (defun erl-wrangler-code-inspector-nested-cases(level)
;;   "Sematic search of instances of a variable"
;;   (interactive (list (read-string "Nest level: ")))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (if (y-or-n-p "Only check the current buffer?")
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 
;;                        'inspec_lib 'nested_exprs_in_file 
;;                        (list current-file-name level 'case hare-search-paths tab-width))
;;          (erl-receive (buffer)
;;              ((['rex ['badrpc rsn]]
;;                (message "Error: %S" rsn))
;;               (['rex ['error rsn]]
;;                (message "Error: %s" rsn))
;;               (['rex ['ok regions]]
;;                (message "Searching finished.")
;;                ))))
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 
;;                      'inspec_lib 'nested_exprs_in_dirs 
;;                      (list level 'case hare-search-paths tab-width))
;;        (erl-receive (buffer)
;;            ((['rex ['badrpc rsn]]
;;              (message "Error: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Error: %s" rsn))
;;             (['rex ['ok regions]]
;;              (message "Searching finished.")
;;              )))))
;;       (message "Searching aborted."))))



;; (defun erl-wrangler-code-inspector-nested-ifs(level)
;;   "Sematic search of instances of a variable"
;;   (interactive (list (read-string "Nest level: ")))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;              (if (y-or-n-p "Only check the current buffer?")
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 'inspec_lib 'nested_exprs_in_file 
;;                              (list current-file-name level 'if hare-search-paths tab-width))
;;          (erl-receive (buffer)
;;              ((['rex ['badrpc rsn]]
;;                (message "Error: %S" rsn))
;;               (['rex ['error rsn]]
;;                (message "Error: %s" rsn))
;;               (['rex ['ok regions]]
;;                (message "Searching finished.")
;;                ))))
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'inspec_lib 
;;                            'nested_exprs_in_dirs (list level 'if hare-search-paths tab-width))
;;        (erl-receive (buffer)
;;            ((['rex ['badrpc rsn]]
;;              (message "Error: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Error: %s" rsn))
;;             (['rex ['ok regions]]
;;              (message "Searching finished.")
;;              )))))
;;       (message "Searching aborted."))))
       

;; (defun erl-wrangler-code-inspector-nested-receives(level)
;;   "Sematic search of instances of a variable"
;;   (interactive (list (read-string "Nest level: ")))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (if (y-or-n-p "Only check the current buffer?")
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 'inspec_lib 'nested_exprs_in_file 
;;                              (list current-file-name level 'receive hare-search-paths tab-width))
;;          (erl-receive (buffer)
;;              ((['rex ['badrpc rsn]]
;;                (message "Error: %S" rsn))
;;               (['rex ['error rsn]]
;;                (message "Error: %s" rsn))
;;               (['rex ['ok regions]]
;;                (message "Searching finished.")
;;                ))))
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'inspec_lib 'nested_exprs_in_dirs 
;;                            (list level 'receive hare-search-paths tab-width))
;;        (erl-receive (buffer)
;;            ((['rex ['badrpc rsn]]
;;              (message "Error: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Error: %s" rsn))
;;             (['rex ['ok regions]]
;;              (message "Searching finished.")
;;              )))))
;;       (message "Searching aborted."))))
      



;; (defun erl-wrangler-code-inspector-caller-called-mods()
;;   "Sematic search of instances of a variable"
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if  (buffers-saved)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'inspec_lib 'dependencies_of_a_module
;;                            (list current-file-name hare-search-paths))
;;        (erl-receive (buffer)
;;            ((['rex ['badrpc rsn]]
;;              (message "Error: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Error: %s" rsn))
;;             (['rex ['ok regions]]
;;              (message "Analysis finished.")
;;             ))))
;;       (message "Refactoring aborted."))))


;; (defun erl-wrangler-code-inspector-long-funs(lines)
;;   "Search for long functions"
;;   (interactive (list (read-string "Number of lines: ")))
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;              (if (y-or-n-p "Only check the current buffer?")
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 'inspec_lib 'long_functions_in_file 
;;                              (list current-file-name lines hare-search-paths tab-width))
;;          (erl-receive (buffer)
;;              ((['rex ['badrpc rsn]]
;;                (message "Error: %S" rsn))
;;               (['rex ['error rsn]]
;;                (message "Error: %s" rsn))
;;               (['rex ['ok regions]]
;;                (message "Searching finished.")
;;                ))))
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'inspec_lib 'long_functions_in_dirs 
;;                            (list lines hare-search-paths tab-width))
;;        (erl-receive (buffer)
;;            ((['rex ['badrpc rsn]]
;;              (message "Error: %S" rsn))
;;             (['rex ['error rsn]]
;;              (message "Error: %s" rsn))
;;             (['rex ['ok regions]]
;;              (message "Searching finished.")
;;              )))))
;;       (message "Searching aborted."))))


;; (defun erl-wrangler-code-inspector-large-mods(lines)
;;   "Search for large modules"
;;   (interactive (list (read-string "Number of lines: ")))
;;   (let       (buffer (current-buffer))
;;     (if (buffers-saved)
;;       (erl-spawn
;;      (erl-send-rpc wrangler-erl-node 'inspec_lib 'large_modules 
;;                          (list lines hare-search-paths tab-width))
;;      (erl-receive (buffer)
;;          ((['rex ['badrpc rsn]]
;;            (message "Searching for large modules failed: %S" rsn))
;;           (['rex ['error rsn]]
;;            (message "Searching for large modules failded: %s" rsn))
;;           (['rex ['ok mods]]
;;            (message "Searching finished.")
;;            ))))
;;       (message "Searching aborted."))))

;; (defun erl-wrangler-code-inspector-caller-funs()
;;   "Search for caller functions"
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (line-no           (current-line-no))
;;         (column-no         (current-column-no))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node
;;                      'inspec_lib 'calls_to_fun
;;                      (list current-file-name line-no column-no  hare-search-paths tab-width))
;;        (erl-receive (buffer)
;;          ((['rex ['badrpc rsn]]
;;            (message "Searching for calls to a function: %S" rsn))
;;           (['rex ['error rsn]]
;;            (message "Searching for calls to a function: %s" rsn))
;;           (['rex ['ok funs]]
;;            (message "Searching finished.")))))
;;       (message "Searching aborted.")
;;       )))


;; (defun erl-wrangler-code-inspector-non-tail-recursive-servers()
;;   "Search for non tail-recursive servers"
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (if (y-or-n-p "Only check the current buffer?")
;;          (erl-spawn
;;            (erl-send-rpc wrangler-erl-node 'inspec_lib 'non_tail_recursive_servers_in_file 
;;                                (list current-file-name hare-search-paths tab-width))
;;            (erl-receive (buffer)
;;                ((['rex ['badrpc rsn]]
;;                  (message "Searching failed: %S" rsn))
;;                 (['rex ['error rsn]]
;;                  (message "Searching failed: %s" rsn))
;;                 (['rex ['ok regions]]
;;                  (message "Searching finished.")
;;                  ))))
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 
;;                        'inspec_lib  'non_tail_recursive_servers_in_dirs 
;;                        (list hare-search-paths tab-width))
;;          (erl-receive (buffer)
;;              ((['rex ['badrpc rsn]]
;;                (message "Searching failed: %S" rsn))
;;               (['rex ['error rsn]]
;;                (message "Searching failed: %s" rsn))
;;               (['rex ['ok regions]]
;;                (message "Searching finished.")
;;                )))))
;;       (message "Searching aborted.")
;;       )))
      
          

;; (defun erl-wrangler-code-inspector-no-flush()
;;   "Search for servers without flush of unknown messages"
;;   (interactive)
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (if (y-or-n-p "Only check the current buffer?")
;;          (erl-spawn
;;            (erl-send-rpc wrangler-erl-node 'inspec_lib 'not_flush_unknown_messages_in_file 
;;                                (list current-file-name hare-search-paths tab-width))
;;            (erl-receive (buffer)
;;                ((['rex ['badrpc rsn]]
;;                  (message "Searching failed: %S" rsn))
;;                 (['rex ['error rsn]]
;;                  (message "Searching failed: %s" rsn))
;;                 (['rex ['ok regions]]
;;                  (message "Searching finished.")
;;                  ))))
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 'inspec_lib 'not_flush_unknown_messages_in_dirs 
;;                              (list hare-search-paths tab-width))
;;          (erl-receive (buffer)
;;              ((['rex ['badrpc rsn]]
;;                (message "Searching failed: %S" rsn))
;;               (['rex ['error rsn]]
;;                (message "Searching faild: %s" rsn))
;;               (['rex ['ok regions]]
;;                (message "Searching finished.")
;;                ))))
;;        )
;;       (message "Searching aborted."))))
 

   
(defun get-file-buffer-1(f)
  (if (featurep 'xemacs)
      (progn
        (setq file-buffer nil)
        (setq buffers (buffer-list))
        (setq f1 (replace-in-string f "/" "\\\\"))
        (while (and (not file-buffer) (not (equal buffers nil)))
           (let ((filename (buffer-file-name (car buffers))))
             (if filename
                 (progn
                   (if (equal (downcase f1) (downcase filename))
                       (setq file-buffer (car buffers))
                     (setq buffers (cdr buffers)))
                   )
               (setq buffers (cdr buffers))
               )))
        file-buffer)
    (get-file-buffer f)))


;; (defun erl-wrangler-code-inspector-callgraph(outputfile)
;;   "Generate function callgraph for a module"
;;   (interactive (list (read-file-name "Output .dot file name: " nil nil nil "callgraph.dot")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;         (outputfile1 (expand-file-name outputfile)))
;;     (if (buffers-saved)
;;      (erl-spawn
;;            (erl-send-rpc wrangler-erl-node 'inspec_lib 'gen_function_callgraph 
;;                                (list outputfile1 current-file-name hare-search-paths))
;;            (erl-receive (outputfile1)
;;                ((['rex ['badrpc rsn]]
;;                  (message "Callgraph generation failed: %S" rsn))
;;                 (['rex ['error rsn]]
;;                  (message "Callgraph generation failed: %s" rsn))
;;                 (['rex 'true]
;;                  (find-file outputfile1)
;;                  (message "Function callgraph generation finished.")))))
;;       (message "Callgraph generation aborted."))))
 

;; (defun erl-wrangler-code-inspector-module-scc-graph(outputfile)
;;   "Generate module scc graph"
;;   (interactive (list (read-file-name "Output .dot file name: " nil nil nil "modulegraph.dot")))                                
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer))
;;         (outputfile1 (expand-file-name outputfile)))
;;     (if (buffers-saved)
;;      (progn
;;        (if (y-or-n-p "Label edges with function names called?")
;;            (setq withlabel 'true)
;;          (setq withlabel 'false)
;;          )
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 'inspec_lib 'gen_module_scc_graph 
;;                              (list outputfile1 hare-search-paths withlabel))
;;          (erl-receive (outputfile1)
;;              ((['rex ['badrpc rsn]] 
;;                (message "Module SCC graph generation failed: %S" rsn))
;;               (['rex ['error rsn]]
;;                  (message "Module SCC graph generation failed: %s" rsn))
;;               (['rex 'true]
;;                (find-file outputfile1)
;;                (message "Module SCC graph generation finished.")))))
;;        )
;;       (message "Module SCC graph generation aborted."))))
 

;; (defun erl-wrangler-code-inspector-module-graph(outputfile)
;;   "Generate module graph"
;;   (interactive (list (read-file-name "Output .dot file name: " nil nil nil "modulegraph.dot")))
;;   (if (y-or-n-p (format "Generate module graph for modules in the following directories: %s" hare-search-paths))
;;       (let ((current-file-name (buffer-file-name))
;;          (buffer (current-buffer))
;;             (outputfile1 (expand-file-name outputfile)))
;;      (if (buffers-saved)
;;          (progn
;;            (if (y-or-n-p "Label edges with function names called?")
;;                (setq withlabel 'true)
;;              (setq withlabel 'false)
;;              )
;;            (erl-spawn
;;              (erl-send-rpc wrangler-erl-node 'inspec_lib 'gen_module_graph 
;;                                  (list outputfile1 hare-search-paths withlabel))
;;              (erl-receive (outputfile1)
;;                  ((['rex ['badrpc rsn]]
;;                  (message "Module graph generation failed: %S" rsn))
;;                   (['rex ['error rsn]]
;;                    (message "Module graph generation failed: %s" rsn))
;;                   (['rex 'true]
;;                    (find-file outputfile1)
;;                    (message "Module graph generation finished."))))))
;;        (message "Module graph generation aborted.")))
;;     (message "Please customize Wrangler SearchPaths to generate modulegraph for other directories.")))


;; (defun erl-wrangler-code-inspector-cyclic-graph(outputfile)
;;   "Detect cyclic module dependencies"
;;   (interactive (list (read-file-name "Output .dot file name: " nil nil nil "cyclic_module_dependency.dot")))              
;;   (if (y-or-n-p (format "Check for modules in the following directories: %s" hare-search-paths))
;;       (let ((current-file-name (buffer-file-name))
;;          (buffer (current-buffer))
;;             (outputfile1 (expand-file-name outputfile)))
;;      (if (buffers-saved)
;;          (progn
;;            (if (y-or-n-p "Label edges with function names called?")
;;                (setq withlabel 'true)
;;              (setq withlabel 'false)
;;              )
;;            (erl-spawn
;;              (erl-send-rpc wrangler-erl-node 'inspec_lib 'cyclic_dependent_modules 
;;                                  (list outputfile1 hare-search-paths withlabel))
;;              (erl-receive (outputfile1)
;;                  ((['rex ['badrpc rsn]]
;;                  (message "Cyclic module dependency detection failed: %s" rsn))
;;                   (['rex ['error rsn]]
;;                    (message "Cyclic module dependency detection failed: %s" rsn))
;;                   (['rex 'true]
;;                    (find-file outputfile1)
;;                    (message "Cyclic module dependency detection finished."))))))
;;        (message "Cyclic module dependency detection aborted.")))
;;     (message "Please customize Wrangler SearchPaths to check for modules in other directories.")))


;; (defun erl-wrangler-code-inspector-improper-module-dependency(outputfile)
;;   "Detect improper module dependency"
;;   (interactive (list (read-file-name "Output .dot file name: " nil nil nil "improper_module_dependency.dot")))                    
;;   (if (y-or-n-p (format "Check for modules in the following directories: %s" hare-search-paths))
;;       (let ((current-file-name (buffer-file-name))
;;          (buffer (current-buffer))
;;             (outputfile1 (expand-file-name outputfile)))
;;      (if (buffers-saved)
;;          (progn
;;            (erl-spawn
;;              (erl-send-rpc wrangler-erl-node 'inspec_lib 'improper_inter_module_calls
;;                                  (list outputfile1 hare-search-paths))
;;              (erl-receive (outputfile1)
;;                  ((['rex ['badrpc rsn]]
;;                    (message "Improper module dependency detection failed: %S" rsn))
;;                   (['rex ['error rsn]]
;;                    (message "Improper module dependency detection failed: %s" rsn))
;;                   (['rex 'true]
;;                    (find-file outputfile1)
;;                    (message "Improper module dependency detection finished."))))))
;;        (message "Improper module depdendency detection aborted.")))
;;     (message "Please customize Wrangler SearchPaths to check for modules in other directories.")))


;; (defun erl-wrangler-code-inspector-partition-exports(distthreshold)
;;   "Partition functions exported by a module"
;;   (interactive (list 
;;              (read-string "Please input a distance threshould between 0 and 1.0 (default value: 0.8):")
;;              ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;     (if (buffers-saved)
;;      (progn
;;        (erl-spawn
;;          (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                           (list 'partition_exports 
;;                                 (list current-file-name distthreshold hare-search-paths 'emacs tab-width)
;;                                 hare-search-paths))
;;          (erl-receive (buffer current-file-name)
;;              ((['rex ['badrpc rsn]]
;;                (message "Partition of exported functions failed: %S" rsn))
;;               (['rex ['error rsn]]
;;                (message "Partition of exported functions failed: %s" rsn))
;;               (['rex ['ok modified]]
;;                (preview-commit-cancel current-file-name modified nil)
;;                (message "Partition of exported functions finished."))))))
;;       (message "Partition of exported functions aborted."))))
   
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; The following functions are for monitoring refactoring activities purpose, and ;;
;; will be moved to a separate module.                                            ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (defun backend-used()
;;   "Get the version control system used by the monitor"
;;   version-control-system)

;;   ;;   (vc-responsible-backend (concat (file-name-as-directory  refac-monitor-repository-path) ".")))

;;  (defun update-repository(files logmsg)
;;   "commit refactoring files to the monitoring repository if they should be monitored"
;;   (if (or (equal files nil) (equal dirs-to-monitor nil))
;;       nil
;;     (let ((dir (is-a-monitored-file (elt (car files) 0))))
;;       (if (equal nil dir)
;;        nil
;;      (let ((extended-logmsg (concat "Time:" (current-time-string)
;;                                     ", User:" (number-to-string (wrangler-t-hash (user-login-name)))
;;                                        ", " logmsg)))
;;        (cond
;;         ((equal version-control-system 'ClearCase)
;;          (add-logmsg-to-logfile-clearcase extended-logmsg))
;;         ((or (equal version-control-system 'Git)
;;              (equal version-control-system 'SVN))
;;          (progn
;;            (setq olddir default-directory)
;;            (cd refac-monitor-repository-path)
;;            (update-repository-1 dir (concat hare-version extended-logmsg))
;;            (cd olddir)
;;            ))
;;         (t nil))
;;        )
;;      )
;;       )
;;     )
;;   )

;; (defun update-repository-1 (dir-to-monitor logmsg)
;;   "log refactoring command and souce code is flag is set"
;;   (if (equal log-source-code 't)
;;       (update-repository-2 dir-to-monitor logmsg)
;;     (update-repository-3 dir-to-monitor logmsg)))

;; (defun update-repository-2 (dir-to-monitor logmsg)
;;   "copy changed files to the working copy of refactor monitor"
;;   (require 'dired-aux)
;;   (let* ((refac-monitor-path (concat (file-name-as-directory refac-monitor-repository-path)
;;                                   (file-name-nondirectory dir-to-monitor)))
;;       (logfile (concat (file-name-as-directory refac-monitor-path) "refac_cmd_log")))
;;     (copy-dir-recursive  dir-to-monitor refac-monitor-path 'true nil nil 'always)
;;     (write-region (concat "\n" logmsg) nil logfile 'true)
;;     (register-and-checkin-new-files refac-monitor-path (list logfile) logmsg)
;;     ))
    

;; (defun update-repository-3 (dir-to-monitor logmsg)
;;   "update refac_cmd_log"
;;   (let* ((logfile (concat (file-name-as-directory refac-monitor-repository-path) "refac_cmd_log"))
;;          )
;;     (write-region (concat "\n" logmsg) nil logfile 'true)
;;     ))

    
;; (defun copy-dir-recursive (from to ok-flag &optional preserve-time top recursive)
;;   (let ((attrs (file-attributes from))
;;      dirfailed)
;;     (if (and recursive
;;           (equal t (car attrs))
;;           (or (equal recursive 'always)
;;               (yes-or-no-p (format "Recursive copies of %s? " from))))
;;      ;; This is a directory
;;      (if (or (member (file-name-nondirectory from) vc-directory-exclusion-list)
;;          (and (string-equal (substring (file-name-nondirectory from) 0 1) ".")
;;               (not (or (string-equal (file-name-nondirectory from) ".")
;;                        (string-equal (file-name-nondirectory from) "..")))))
;;          nil
;;        (let ((mode (or (file-modes from) #o700))
;;              (files
;;               (condition-case err
;;                   (directory-files from nil  "^\\([^.]\\|\\.\\([^.]\\|\\..\\)\\).*")
;;                 (file-error
;;                (push (dired-make-relative from)
;;                      dired-create-files-failures)
;;                (dired-log "Copying error for %s:\n%s\n" from err)
;;                (setq dirfailed t)
;;                nil))))
;;          (if (equal recursive 'top) (setq recursive 'always)) ; Don't ask any more.
;;          (unless dirfailed
;;            (if (file-exists-p to)
;;                (or top (dired-handle-overwrite to))
;;              (condition-case err
;;                  ;; We used to call set-file-modes here, but on some
;;                  ;; Linux kernels, that returns an error on vfat
;;                  ;; filesystems
;;                  (let ((default-mode (default-file-modes)))
;;                    (unwind-protect
;;                        (progn
;;                          (set-default-file-modes #o700)
;;                          (make-directory to))
;;                      (set-default-file-modes default-mode)))
;;                (file-error
;;                 (push (dired-make-relative from)
;;                       dired-create-files-failures)
;;                 (setq files nil)
;;                 (dired-log "Copying error for %s:\n%s\n" from err)))))
;;          (dolist (file files)
;;            (let ((thisfrom (expand-file-name file from))
;;                  (thisto (expand-file-name file to)))
;;              ;; Catch errors copying within a directory,
;;              ;; and report them through the dired log mechanism
;;              ;; just as our caller will do for the top level files.
;;              (condition-case err
;;                  (copy-dir-recursive
;;                   thisfrom thisto
;;                   ok-flag preserve-time nil recursive)
;;                (file-error
;;                 (push (dired-make-relative thisfrom)
;;                       dired-create-files-failures)
;;                 (dired-log "Copying error for %s:\n%s\n" thisfrom err)))))
;;          (when (file-directory-p to)
;;            (set-file-modes to mode))))
;;       ;; Not a directory.
;;       (or top (dired-handle-overwrite to))
;;       (condition-case err
;;        (if (stringp (car attrs))
;;            ;; It is a symlink
;;            (make-symbolic-link (car attrs) to ok-flag)
;;          (if (and (or (equal (file-name-extension from) "erl")
;;                       (equal (file-name-extension from) "hrl"))
;;                   (not (backup-file-name-p from)))
;;              (progn
;;              ;;  (message "filetocopy:%s" from)
;;                (copy-file from to ok-flag dired-copy-preserve-time)
;;                )
;;            nil))
;;      (file-date-error
;;       (push (dired-make-relative from)
;;             dired-create-files-failures)
;;       (dired-log "Can't set date on %s:\n%s\n" from err))))))

     

;; (defun collect-files-svn (dir-to-check)
;;   "Expands directories in a file list specification.
;;       Within directories, only files not already under version control are noticed."
;;   (let ((file-or-dir-list (list dir-to-check)))
;;     (let ((flattened '()))
;;       (dolist (node file-or-dir-list)
;;      (when (file-directory-p node)
;;        (file-tree-walk
;;         (expand-file-name node) 
;;         (lambda (f) 
;;           (if (or (equal (file-name-extension f) "erl") (equal (file-name-extension f) "hrl"))
;;               (push f flattened)
;;             flattened))
;;         nil))
;;      ;;(unless (file-directory-p node) (push node flattened))
;;      (push node flattened)
;;      )
;;       flattened)))

;; (defun collect-files-git (dir-to-check)
;;   "Expands directories in a file list specification.
;;       Within directories, only files not already under version control are noticed."
;;   (let ((file-or-dir-list (list dir-to-check)))
;;     (let ((flattened '()))
;;       (dolist (node file-or-dir-list)
;;      (when (file-directory-p node)
;;        (file-tree-walk
;;         (expand-file-name node) 
;;         (lambda (f) 
;;           (if (or (equal (file-name-extension f) "erl") (equal (file-name-extension f) "hrl"))
;;               (push f flattened)
;;             flattened))
;;         nil))
;;      (unless (file-directory-p node) (push node flattened))
;;      )
;;       flattened)))


;; (defun file-tree-walk (file func args)
;;   (if (not (file-directory-p file))
;;       (apply func file args)
;;     (let ((dir (file-name-as-directory file)))
;;        (mapcar
;;        (lambda (f) (or
;;                  (string-equal f ".")
;;                  (string-equal f "..")
;;                  (member f vc-directory-exclusion-list)
;;                  (let ((dirf (expand-file-name f dir)))
;;                    (file-tree-walk dirf func args))))
;;        (directory-files dir)))))

;; (defun register-and-checkin-new-files(dir-to-check logfile logmsg)
;;   "Register and check new files into the version control system."
;;   ;;(message "Current directory being checked: %s" dir-to-check)
;;   (if (equal (backend-used) 'SVN)
;;       (progn
;;      (let ((files (collect-files-svn dir-to-check)))
;;        (register 'SVN nil (list dir-to-check) "new directory")
;;        (checkin 'SVN (list dir-to-check) logmsg)))
;;     (progn
;;       (let ((files (collect-files-git dir-to-check)))
;;      (setq files1 (mapcar #'(lambda (f) (file-relative-name f refac-monitor-repository-path)) files))
;;      (register 'Git nil logfile "new directory")
;;      (checkin 'Git logfile logmsg)
;;      ))))



;; (defun register (backend &optional set-revision files comment)
;;   (if (>= emacs-major-version  23)
;;       (progn
;;      (vc-call-backend backend 'register files nil comment)
;;      (dolist (file files)
;;       ;; (message "current file to set prop: %s" file)
;;        (vc-file-setprop file 'vc-backend backend)
;;        ))
;;     (progn
;;       (dolist (file files)
;;      ;;(message "current file to set prop: %s" file)
;;      (vc-call-backend backend 'register file nil comment)
;;      (vc-file-setprop file 'vc-backend backend)
;;      ))))
  

 
;; (defun checkin (backend files comment)
;;   (dolist (file files)
;;     ;;(message "file being commited: %s" file)
;;     (unless (file-writable-p file)
;;       (set-file-modes file (logior (file-modes file) 128))
;;       (let ((visited (get-file-buffer-1 file)))
;;      (when visited
;;        (with-current-buffer visited
;;          (toggle-read-only -1))))))
;;   (if (not files)
;;       nil
;;     (if (equal backend 'SVN)
;;      (progn
;;        (if (>= emacs-major-version  23)
;;            (vc-call-backend backend 'checkin files nil comment)
;;          (dolist (file files)
;;            (vc-call-backend backend 'checkin file nil comment)
;;            ))
;;        )
;;       (progn 
;;      (if (>= emacs-major-version  23)
;;          (vc-call-backend backend 'checkin files nil comment)
;;        (dolist (file files)
;;          (vc-git-command nil 'async file "commit" "-m" comment "--only" "--")
;;          ))))
;;   ))
 
    
;; (defun write-to-refac-logfile(dir-to-monitor logmsg checkin-comment)
;;   "write log infomation to the log file and check in to the repository"
;;   (let* ((refac-monitor-path (concat (file-name-as-directory refac-monitor-repository-path)
;;                                   (file-name-nondirectory dir-to-monitor)))
;;       (logfile (if (equal log-source-code 't)
;;                       (concat (file-name-as-directory refac-monitor-path) "refac_cmd_log")
;;                     (concat (file-name-as-directory refac-monitor-repository-path) "refac_cmd_log")))
;;       (exist (file-regular-p logfile)))
;;     (write-region (concat "\n" logmsg) nil logfile 'true)
;;     (if (equal log-source-code 't)
;;         (progn
;;           (setq olddir default-directory)
;;           (cd refac-monitor-repository-path)
;;           (setq logfile1 (file-relative-name logfile refac-monitor-repository-path))
;;           (if (equal exist nil)
;;               (register (backend-used) nil (list logfile1) "new file")
;;             nil) 
;;           (checkin (backend-used) (list logfile1) checkin-comment)
;;           (cd olddir))
;;       nil)
;;     ))

;; (defun wrangler-t-hash (str)
;;   "Portably hash string STR.
;; The hash value is portable across 32 and 64 bit Emacsen, across
;; Linux and Solaris. For 4287 userids, there are only 11 collisions.
;; Based on the hash function in http://www.haible.de/bruno/hashfunc.html."
;;   (let* ((chars (append str nil))
;;         (h 0)
;;         (word-len 25)
;;         (nbits-left 7)
;;         (nbits-right (- (- word-len nbits-left)))
;;         (mask (- (lsh 1 word-len) 1)))
;;     (while chars
;;       (setq h (logior (logand (lsh h nbits-left) mask) (lsh h nbits-right)))
;;       (setq h (logand (+ h (car chars)) mask))
;;       (setq chars (cdr chars)))
;;     h))



;; (defun my-region-beginning()
;;   "Get the region beginning is some text is highlight, otherwise 
;;    return 0"
;;   (condition-case nil
;;       (region-beginning)
;;     (error 0)
;;     ))

;; (defun my-region-end()
;;   "Get the region beginning is some text is highlight, otherwise 
;;    return 0"
;;   (condition-case nil
;;       (region-end)
;;     (error 0)
;;     ))


;; (defun  add_to_my_gen_refac_menu_items()
;;    "Add a user-defined refactoring to menu."
;;    (interactive) 
;;    (let ((current-file-name (buffer-file-name)))
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'wrangler_add_new_refac 'add 
;;                      (list current-file-name 'gen_refac 
;;                            my_gen_refac_menu_items 'emacs 'none (getenv "HOME")))
;;        (erl-receive ()
;;            ((['rex ['badrpc rsn]]
;;              (message "Wrangler failed to add the new menu item: %s" rsn))
;;             (['rex ['error rsn]]
;;              (message "Wrangler failed to add the new menu item: %s" rsn))
;;             (['rex ['ok el_filename]]
;;              (load el_filename)
;;              (hare-menu-remove)
;;              (hare-menu-init)
;;              (message "New menu item added successfully."))))
;;        ))) 


;; (defun  remove_from_my_gen_refac_menu_items(name)
;;    "Remove a user-defined refactoring from menu."
;;    (interactive (list (read-string "Menu item name: "))) 
;;    (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'wrangler_add_new_refac 'remove 
;;                      (list name 'gen_refac 
;;                            my_gen_refac_menu_items 'emacs 'none (getenv "HOME")))
;;        (erl-receive ()
;;            ((['rex ['badrpc rsn]]
;;              (message "Wrangler failed to remove the menu item: %s" rsn))
;;             (['rex ['error rsn]]
;;              (message "Wrangler failed to remove the menu item: %s" rsn))
;;             (['rex ['ok el_filename1 el_filename2]]
;;              (load el_filename1)
;;              (load el_filename2)
;;              (hare-menu-remove)
;;              (hare-menu-init)
;;              (message "Menu item removed successfully."))))
;;        ))


;; (defun  add_to_my_gen_composite_refac_menu_items()
;;    "Add a user-defined refactoring to menu."
;;    (interactive) 
;;    (let ((current-file-name (buffer-file-name)))
;;      (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'wrangler_add_new_refac 'add 
;;                      (list current-file-name 'gen_composite_refac 
;;                            my_gen_composite_refac_menu_items
;;                            'emacs 'none (getenv "HOME")))
;;        (erl-receive ()
;;            ((['rex ['badrpc rsn]]
;;              (message "Wrangler failed to add the new menu item: %s" rsn))
;;             (['rex ['error rsn]]
;;              (message "Wrangler failed to add the new menu item: %s" rsn))
;;             (['rex ['ok el_filename]]
;;              (load el_filename)
;;              (hare-menu-remove)
;;              (hare-menu-init)
;;              (message "New menu item added successfully."))))
;;        ))) 
 

;; (defun remove_from_my_gen_composite_refac_menu_items(name)
;;    "Remove a user-defined refactoring from menu."
;;    (interactive (list (read-string "Menu item name: "))) 
;;    (erl-spawn
;;        (erl-send-rpc wrangler-erl-node 'wrangler_add_new_refac 'remove 
;;                      (list name 'gen_composite_refac 
;;                            my_gen_composite_refac_menu_items 'emacs 'none (getenv "HOME")))
;;        (erl-receive ()
;;            ((['rex ['badrpc rsn]]
;;              (message "Wrangler failed to remove the menu item: %s" rsn))
;;             (['rex ['error rsn]]
;;              (message "Wrangler failed to remove the menu item: %s" rsn))
;;             (['rex ['ok el_filename1 el_filename2]]
;;              (load el_filename1)
;;              (load el_filename2)
;;              (hare-menu-remove)
;;              (hare-menu-init)
;;              (message "Menu item removed successfully."))))
;;        ))

;; (defun apply-adhoc-refac(callback-module-name) 
;;   "Get the parameters that need inputs from the user"
;;   (interactive (list (read-string "Refactoring Callback module name: ")))
;;   (let* ((buffer (current-buffer))
;;         (current-file-name (buffer-file-name))
;;         (line-no (current-line-no))
;;         (column-no (current-column-no))
;;         (region-begin (my-region-beginning))
;;         (region-end   (my-region-end))
;;         (start-line-no (line-no-pos region-begin))
;;         (start-col-no  (current-column-pos region-begin))
;;         (end-line-no   (line-no-pos region-end))
;;         (end-col-no    (current-column-pos region-end)))
;;      (if (current-buffer-saved buffer)
;;         (erl-spawn
;;           (erl-send-rpc wrangler-erl-node 'gen_refac 'input_par_prompts (list callback-module-name))
;;           (erl-receive (buffer current-file-name callback-module-name line-no column-no 
;;                                start-line-no start-col-no end-line-no end-col-no)
;;               ((['rex ['badrpc rsn]]
;;                 (message "Refactoring failed: the refactoring does not exist!"))        
;;                (['rex ['error rsn]]
;;                 (message "Refactoring failed: error, %s" rsn))
;;                (['rex ['ok pars]]
;;                 (apply-adhoc-refac-1 callback-module-name current-file-name line-no column-no 
;;                                      start-line-no start-col-no end-line-no end-col-no pars)
;;                 ))))
;;        (message "Refactoring aborted."))))

;; (defun apply-adhoc-refac-1(callback-module-name current-file-name line-no column-no 
;;                            start-line-no start-col-no end-line-no end-col-no pars)  
;;   "apply a user-defined refactoring/transformation"
;;   (interactive)
;;   (let* ((par_vals (mapcar 'read-string pars)) 
;;          (buffer (current-buffer))
;;          (args (list callback-module-name 
;;                      (list current-file-name  (list line-no column-no) (list (list start-line-no start-col-no)
;;                                                                              (list end-line-no end-col-no))
;;                            par_vals hare-search-paths tab-width))))
;;     (if (current-buffer-saved buffer)
;;         (progn
;;           (erl-spawn
;;             (erl-send-rpc wrangler-erl-node 'gen_refac 'run_refac args)
;;             (erl-receive (current-file-name buffer)
;;                 ((['rex ['badrpc rsn]]
;;                   (message "Refactoring failed: %s" rsn))
;;                  (['rex ['error rsn]]
;;                   (message "Refactoring failed: %s" rsn))
;;                  (['rex ['change_set changes callback-module args]]
;;                   (if (equal changes nil)
;;                       (message "Refactoring finished, and no file has been changed.")
;;                      (progn
;;                        (setq candidates-not-to-change (get-candidates-not-to-change changes))
;;                        (if (equal (length candidates-not-to-change) (length changes))
;;                            (message "Refactoring finished, and no file has been changed.")
;;                          (erl-spawn
;;                            (erl-send-rpc wrangler-erl-node 'gen_refac 'apply_changes 
;;                                          (list callback-module args candidates-not-to-change))
;;                            (erl-receive (current-file-name)
;;                                ((['rex ['badrpc rsn]] 
;;                                  (message "Refactoring failed: %S" rsn))
;;                                 (['rex ['error rsn]]
;;                                  (message "Refactoring failed: %s" rsn))
;;                                 (['rex ['ok modified]]
;;                                  (preview-commit-cancel current-file-name modified nil)
;;                                  ))))))))
;;                  (['rex ['ok modified]]
;;                   (progn
;;                     (if (equal modified nil)
;;                         (message "Refactoring finished, and no file has been changed.")
;;                       (preview-commit-cancel current-file-name modified nil)
;;                       ))
;;                   ))))
;;           )
;;       (message "Refactoring aborted."))))

;; (defun apply-my-code-inspection(module-name function-name)
;;   "get the parameters that need inputs from the user"
;;   (interactive (list (read-string "Code inspection module name: ")
;;                      (read-string "Code inspection function name: ")))
;;   (let* 
;;       ((current-file-name (buffer-file-name))
;;        (buffer (current-buffer))
;;        (line-no (current-line-no))
;;        (column-no (current-column-no)))
;;     (if (current-buffer-saved buffer) 
;;         (erl-spawn            
;;           (erl-send-rpc wrangler-erl-node 'emacs_inspec 'input_par_prompts (list module-name function-name))             
;;           (erl-receive (buffer module-name function-name current-file-name) 
;;               ((['rex ['badrpc rsn]]
;;                 (message "Code inspection failed: %s" rsn))
;;                  (['rex ['error rsn]]
;;                   (message "Code inspection failed: %s" rsn))
;;                  (['rex ['ok pars]]
;;                   (apply-code-inspection module-name function-name current-file-name pars)
;;                   ))))
;;       (message "Code inspection aborted."))))

   
;; (defun apply-code-inspection(module-name function-name current-file-name pars)
;;   "apply a user-defined code inspection function"
;;   (interactive)
;;   (let* 
;;       ((par_vals (mapcar 'read-string pars))
;;        (buffer (current-buffer))
;;        (line-no (current-line-no))
;;        (column-no (current-column-no))
;;        (args (list module-name function-name current-file-name par_vals hare-search-paths tab-width)))
;;     (if (current-buffer-saved buffer)
;;         (erl-spawn
;;           (erl-send-rpc wrangler-erl-node 'emacs_inspec 'apply_code_inspection  (list args))
;;           (erl-receive (buffer) 
;;               ((['rex ['badrpc rsn]]
;;                 (message "Code inspection failed: %s" rsn))
;;                (['rex ['error rsn]]
;;                 (message "Code inspection failed: %s" rsn))
;;                (['rex ['ok res]]
;;                   (message "Code inspection finished.")
;;                   ))))
;;       (message "Code inspection aborted."))))
              

;; (defun get-candidates-not-to-change (candidates) 
;;   (setq candidates-not-to-change nil)
;;   (setq unopened-files nil)
;;   (while (not (equal candidates nil))
;;     (setq new-cand (car candidates))
;;     (setq new-cand-key (elt new-cand 0))
;;     (setq  file-name (elt new-cand-key 0))
;;     (setq line1 (elt new-cand-key 1))
;;     (setq col1  (elt  new-cand-key 2))
;;     (setq line2 (elt new-cand-key 3))
;;     (setq col2  (elt  new-cand-key 4))
;;     (setq new-code (elt new-cand 1))
;;     (if (get-file-buffer-1 file-name)
;;         nil
;;       (setq unopened-files (cons file-name unopened-files))
;;       )
;;     (setq current-buffer (find-file file-name))
;;     (highlight-region line1 col1 line2  col2 current-buffer)
;;     (save-excursion
;;       (with-current-buffer (get-buffer-create "*erl-output*")
;;         (save-selected-window
;;           (select-window (or (get-buffer-window (current-buffer))
;;                              (display-buffer (current-buffer))))
;;           (goto-char (point-max))
;;           (setq pos (point-max))
;;           (insert "*** The code highlighted will be replaced with: ***\n\n")
;;           (insert new-code)
;;           (insert "\n\n")
;;           (set-window-start (get-buffer-window (current-buffer)) pos)
;;           )))
;;     (let ((answer (read-char-spec "Please answer y/n RET to change/not change this candidate, or Y/N RET to change all/none of remaining candidates including the one highlighted: "
;;                                   '((?y y "Answer y to change this candidate;")
;;                                     (?n n "Answer n not to change this candidate;")
;;                                     (?Y Y "Answer Y to fold all the remaining candidates;")
;;                                     (?N N "Answer N to fold none of remaining candidates")))))
;;       (cond ((equal answer 'y)
;;              (setq candidates (cdr candidates)))
;;             ((equal answer 'n)
;;              (setq candidates-not-to-change  (cons new-cand candidates-not-to-change))
;;              (setq candidates (cdr candidates)))
;;             ((equal answer 'Y)
;;              (setq candidates nil))
;;             ((equal answer 'N)
;;              (setq candidates-not-to-change  (append candidates candidates-not-to-change))
;;              (setq candidates nil)))))
;;   (org-delete-overlay highlight-region-overlay)
;;   (dolist (uf unopened-files)
;;     (kill-buffer (get-file-buffer-1 uf)))
;;   (setq unopened-files nil)
;;   candidates-not-to-change)  

;; (defun apply-composite-refac(callback-module-name) 
;;   "Apply a composite refactoring defined by behaviour gen_composite_refac"
;;   (interactive (list (read-string "Refactoring Callback module name: ")))       
;;   (let* ((buffer (current-buffer))
;;         (current-file-name (buffer-file-name))
;;         (line-no (current-line-no))
;;         (column-no (current-column-no))
;;         (region-begin (my-region-beginning))
;;         (region-end   (my-region-end))
;;         (start-line-no (line-no-pos region-begin))
;;         (start-col-no  (current-column-pos region-begin)) 
;;         (end-line-no   (line-no-pos region-end))
;;         (end-col-no    (current-column-pos region-end)))
;;     (if (buffers-saved)
;;         (erl-spawn
;;           (erl-send-rpc wrangler-erl-node 'gen_composite_refac 'input_par_prompts (list callback-module-name))
;;           (erl-receive (buffer current-file-name callback-module-name line-no column-no 
;;                                start-line-no start-col-no end-line-no end-col-no)
;;               ((['rex ['badrpc rsn]]
;;                 (message "Refactoring failed: the refactoring does not exist!"))        
;;                (['rex ['error rsn]]
;;                 (message "Refactoring failed: error, %s" rsn))
;;                (['rex ['ok pars]]
;;                 (apply-composite-refac-1 callback-module-name current-file-name line-no column-no 
;;                                          start-line-no start-col-no end-line-no end-col-no pars)
;;                 ))))
;;       (message "Refactoring aborted."))))


;; (defun apply-composite-refac-1(callback-module-name current-file-name line-no column-no 
;;                            start-line-no start-col-no end-line-no end-col-no pars)  
;;   "apply a composite refactoring"
;;   (interactive)
;;   (if (buffers-saved)
;;       (let* ((par_vals (mapcar 'read-string pars))
;;              (buffer (get-file-buffer-1 current-file-name))
;;              (args (list callback-module-name 
;;                          (list current-file-name  (list line-no column-no) 
;;                                (list (list start-line-no start-col-no)
;;                                      (list end-line-no end-col-no))
;;                                par_vals hare-search-paths tab-width))))
;;         (erl-spawn
;;           (erl-send-rpc wrangler-erl-node 'gen_composite_refac 'init_composite_refac args)
;;           (erl-receive (current-file-name buffer)
;;               ((['rex ['badrpc rsn]]
;;                 (message "Refactoring failed: %s" rsn))
;;                (['rex ['error rsn]]
;;                 (message "Refactoring failed: %s" rsn))
;;                (['rex ['ok pid]]
;;                 (apply-refac-cmds current-file-name (list 'ok nil))
;;                 )))))
;;     (message "Refactoring aborted.")))

;; (defun apply-refac-cmds(current-file-name previous_result)
;;   "apply a sequence of refactoring commands."
;;   (erl-spawn
;;     (erl-send-rpc wrangler-erl-node 'gen_composite_refac 'get_next_command (list previous_result))
;;     (erl-receive (current-file-name)
;;         ((['rex ['badrpc rsn]]
;;           (revert-all-buffers)
;;           (message "Refactoring failed: %s" rsn))
;;          (['rex ['error rsn]]
;;           (revert-all-buffers)
;;           (message "Refactoring failed: %s" rsn))
;;          (['rex ['ok 'none modified ['error rsn]]]
;;           (progn
;;             (revert-all-buffers)
;;             (message "Composite refactoring failed: %s" rsn)))
;;          (['rex ['ok 'none modified msg]] 
;;           (progn
;;              (if (equal modified nil)
;;                  (message "Refactoring finished, and no file has been changed.")
;;                (revert-all-buffers)
;;              ;;  (with-current-buffer (get-file-buffer-1 current-file-name)
;;               ;;  nil)
;;                (preview-commit-cancel current-file-name modified nil)
;;                (message "Refactoring finished."))))
;;          (['rex ['ok ['refactoring cmd args]]]
;;           (apply-a-refac-cmd current-file-name cmd args)) 
;;          (['rex ['ok ['interactive msg cmd args]]]
;;           (if (yes-or-no-p msg)
;;               (apply-a-refac-cmd current-file-name cmd args)
;;             (apply-refac-cmds current-file-name (list 'ok nil))))
;;          (['rex ['ok ['repeat_interactive msg cmd args]]]
;;           (if (yes-or-no-p msg)
;;               (apply-a-refac-cmd current-file-name cmd args) 
;;             (apply-refac-cmds current-file-name 'none)))
;;          (['rex result]
;;           (revert-all-buffers)
;;           (message "Unexpected result: %s" result))
;;          ))))
 
 
;; (defun apply-a-refac-cmd(current-file-name refac_name args)   
;;   "apply a sub refayctoring of a composite refactorings."
;;   (interactive) 
;;   (highlight_sels args)
;;   (setq newargs (get_user_inputs args))
;;   (org-delete-overlay highlight-region-overlay)
;;   (setq refac-function-name (car (cdr (assoc refac_name refac-cmd-name-map))))
;;   (if refac-function-name 
;;       (funcall refac-function-name (append newargs (list tab-width)))
;;     (erl-spawn
;;       (erl-send-rpc wrangler-erl-node 'wrangler_refacs 'try_refac 
;;                     (list 'wrangler_refacs refac_name 
;;                           (append newargs (list tab-width))))
;;       (erl-receive(current-file-name)
;;           ((['rex result]
;;             (process-result (buffer-file-name) result 0 0 t))
;;         ))))
;;   )

;; (defvar refac-cmd-name-map
;;   '((move_fun_by_name erl-refactor-move-fun-composite)
;;     (rename_fun_by_name erl-refactor-rename-fun-composite)
;;     (rename_var  erl-refactor-rename-var-composite)
;;     (fold_expr_by_name erl-refactor-fold-expr-by-name-composite)
;;     (generalise_composite  erl-refactor-generalisation-composite)))


(defun update-buffers(files)
  "update the buffers for files that have been changed"
  (dolist (f files)
    (let ((buffer (get-file-buffer-1 f)))
      (if buffer
          (with-current-buffer buffer (revert-buffer nil t t))
        nil))))

;; (defun get_user_inputs(args)
;;   "get the user input for parameters that need user input."
;;   (interactive)
;;   (setq new-args nil)
;;   (while (not (equal args nil))
;;     (let ((cur-arg (car args)))
;;       (if (sequencep cur-arg)
;;           (progn
;;             (if (equal (elt cur-arg 0) 'prompt)
;;                 (let ((prompt (elt cur-arg 1)))
;;                   (setq new-args (cons (read-string prompt) new-args)))
;;               (setq new-args (cons cur-arg new-args))
;;               ))
;;         (setq new-args (cons cur-arg new-args))
;;         ))
;;     (setq args (cdr args)))
;;   (reverse new-args)
;; )
 

;; (defun highlight_sels(args)
;;   "highlightget the selections."
;;   (interactive)
;;   (while (not (equal args nil))
;;     (let ((cur-arg (car args)))
;;       (if (sequencep cur-arg)
;;           (if(equal (elt cur-arg 0) 'range)
;;               (let ((file (elt (elt cur-arg 1) 0))
;;                     (ranges (elt (elt cur-arg 1) 1)))
;;                 (highlight-instances-with-same-face file ranges))
;;             nil)
;;         nil))
;;     (setq args (cdr args)))
;;   )
 


;; (defun erl-refactor-generate-migration-rules(name)
;;   "generated API migration rules from API interface module."
;;   (interactive (list (read-string "Module name for the API migration rules to be generated: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;   (if (buffers-saved)
;;       (erl-spawn
;;      (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                       (list 'generate_rule_based_api_migration_mod(list current-file-name name)
;;                             hare-search-paths))
;;         (erl-receive (buffer name current-file-name)
;;          ((['rex ['badrpc rsn]]
;;            (message "Refactoring failed: %S" rsn))
;;           (['rex ['error rsn]]
;;            (message "Refactoring failed: %s" rsn))
;;           (['rex ['ok newfile]]
;;               (find-file newfile)
;;               (message "Rule generation finished.")
;;               ))))             
;;     (message "Rule generation aborted."))))

;; (defun erl-refactor-regexp-to-re()
;;     "api migration from regexp to re"
;;     (interactive) 
;;     (let ((current-file-name (buffer-file-name))
;;           (buffer (current-buffer))
;;           (scope (if (yes-or-no-p "Only apply to the current file?")
;;                      (list (buffer-file-name))
;;                    hare-search-paths)))
;;     (if (buffers-saved)
;;         (erl-spawn
;;           (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                         (list 'do_api_migration (list scope "refac_regexp_to_re" 
;;                                                       hare-search-paths 'emacs tab-width)
;;                               hare-search-paths))
;;           (erl-receive (buffer current-file-name)
;;               ((['rex ['badrpc rsn]]
;;                      (message "Refactoring failed: %S" rsn))
;;                (['rex ['error rsn]]
;;                 (message "Refactoring failed: %s" rsn))
;;                (['rex ['ok modified]]
;;                 (if (equal modified nil)
;;                     (message "API migration finished, and no file has been changed.")
;;                   (preview-commit-cancel current-file-name modified nil))))))
;;       (message "API migration aborted."))))

         
       
;; (defun erl-refactor-apply-api-migration-file(name)
;;   "apply API migration rules."
;;   (interactive (list (read-string "API migration rule module: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;   (if (buffers-saved)
;;       (erl-spawn
;;      (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                       (list 'do_api_migration (list (list current-file-name) name 
;;                                                     hare-search-paths 'emacs tab-width)
;;                             hare-search-paths))
;;         (erl-receive (buffer current-file-name)
;;          ((['rex ['badrpc rsn]]
;;            (message "Refactoring failed: %S" rsn))
;;           (['rex ['error rsn]]
;;            (message "Refactoring failed: %s" rsn))
;;           (['rex ['ok modified]]
;;               (if (equal modified nil)
;;                   (message "API migration finished, and no file has been changed.")
;;                 (preview-commit-cancel current-file-name modified nil))))))                         
;;     (message "API migration aborted."))))

;; (defun erl-refactor-apply-api-migration-dirs(name)
;;   "apply API migration rules."
;;   (interactive (list (read-string "API migration rule module: ")
;;                   ))
;;   (let ((current-file-name (buffer-file-name))
;;      (buffer (current-buffer)))
;;   (if (buffers-saved)
;;       (erl-spawn
;;      (erl-send-rpc wrangler-erl-node 'emacs_wrangler 'apply_refac 
;;                       (list 'do_api_migration (list hare-search-paths name hare-search-paths 'emacs tab-width)
;;                             hare-search-paths))
;;         (erl-receive (buffer current-file-name)
;;          ((['rex ['badrpc rsn]]
;;            (message "Refactoring failed: %S" rsn))
;;           (['rex ['error rsn]]
;;            (message "Refactoring failed: %s" rsn))
;;           (['rex ['ok modified]]
;;               (if (equal modified nil)
;;                   (message "API migration finished, and no file has been changed.")
;;                 (preview-commit-cancel current-file-name modified nil))))))                         
;;     (message "API migration aborted."))))

 
;; (require 'tempo)
;; (setq tempo-interactive t)

;; (tempo-define-template "gen-refac"
;;   '((erlang-skel-include erlang-skel-large-header)
;;     "-behaviour(gen_refac)." n n
   
;;     "%% Include files" n 
;;     "-include_lib(\"wrangler/include/wrangler.hrl\")." n n
;;     (erlang-skel-double-separator-start 3)
;;     "%% gen_refac callbacks" n
;;     "-export([input_par_prompts/0,select_focus/1, " n>
;;     "check_pre_cond/1, selective/0, " n>
;;     "transform/1])." n n 

;;     (erlang-skel-double-separator-start 3)
;;     "%%% gen_refac callbacks" n
;;     (erlang-skel-double-separator-end 3)
;;     n
;;     (erlang-skel-separator-start 2)
;;     "%% @private" n 
;;     "%% @doc" n
;;     "%% Prompts for parameter inputs" n
;;     "%%" n
;;     "%% @spec input_par_prompts() -> [string()]" n
;;     (erlang-skel-separator-end 2)
;;     "input_par_prompts() ->" n>
;;     "[]." n
;;     n
;;     (erlang-skel-separator-start 2)
;;     "%% @private" n
;;     "%% @doc" n
;;     "%% Select the focus of the refactoring." n
;;     "%%" n
;;     "%% @spec select_focus(Args::#args{}) ->" n
;;     "%%                {ok, syntaxTree()} |" n
;;     "%%                {ok, none}" n
;;     (erlang-skel-separator-end 2)
;;     "select_focus(_Args) ->" n>
;;     "{ok, none}." n>
;;      n
;;     (erlang-skel-separator-start 2)
;;     "%% @private" n
;;     "%% @doc" n
;;     "%% Check the pre-conditions of the refactoring." n
;;     "%%" n
;;     "%% @spec check_pre_cond(Args#args{}) -> ok | {error, Reason}" n
;;     (erlang-skel-separator-end 2)
;;     "check_pre_cond(_Args) ->" n>
;;     "ok." n
;;     n
;;     (erlang-skel-separator-start 2)
;;     "%% @private" n 
;;     "%% @doc" n
;;     "%% Selective transformation or not." n
;;     "%%" n
;;     "%% @spec selective() -> boolean()" n
;;     (erlang-skel-separator-end 2)
;;     "selective() ->" n>
;;     "false." n
;;     n
;;     (erlang-skel-separator-start 2)
;;     "%% @private" n
;;     "%% @doc" n
;;     "%% This function does the actual transformation." n
;;     "%%" n
;;     "%% @spec transform(Args::#args{}) -> " n
;;     "%%            {ok, [{filename(), filename(), syntaxTree()}]} |" n
;;     "%%            {error, Reason}" n
;;     (erlang-skel-separator-end 2)
;;     "transform(_Args) ->" n>
;;     "{ok, []}." n
;;     n
;;     (erlang-skel-double-separator-start 3)
;;     "%%% Internal functions" n
;;     (erlang-skel-double-separator-end 3)
;;     )
;;   "*The template of a gen_refac.
;; Please see the function `tempo-define-template'.")


;; (tempo-define-template "gen-composite-refac"
;;   '((erlang-skel-include erlang-skel-large-header)
;;     "-behaviour(gen_composite_refac)." n n
   
;;     "%% Include files" n 
;;     "-include_lib(\"wrangler/include/wrangler.hrl\")." n n
;;     (erlang-skel-double-separator-start 3)
;;     "%% gen_composite_refac callbacks" n
;;     "-export([input_par_prompts/0,select_focus/1, " n>
;;     "composite_refac/1])." n n 

;;     (erlang-skel-double-separator-start 3)
;;     "%%% gen_composite_refac callbacks" n
;;     (erlang-skel-double-separator-end 3)
;;     n
;;     (erlang-skel-separator-start 2)
;;     "%% @private" n 
;;     "%% @doc" n
;;     "%% Prompts for parameter inputs" n
;;     "%%" n
;;     "%% @spec input_par_prompts() -> [string()]" n
;;     (erlang-skel-separator-end 2)
;;     "input_par_prompts() ->" n>
;;     "[]." n
;;     n
;;     (erlang-skel-separator-start 2)
;;     "%% @private" n
;;     "%% @doc" n
;;     "%% Select the focus of the refactoring." n
;;     "%%" n
;;     "%% @spec select_focus(Args::#args{}) ->" n
;;     "%%                {ok, syntaxTree()} |" n
;;     "%%                {ok, none}" n
;;     (erlang-skel-separator-end 2)
;;     "select_focus(_Args) ->" n>
;;     "{ok, none}." n>
;;      n
;;     (erlang-skel-separator-start 2)
;;     "%% @private" n
;;     "%% @doc" n
;;     "%% This function defines the composite refactoring script." n
;;     "%%" n
;;     "%% @spec composite_refac(Args::#args{}) -> composite_refac()|[]. " n
;;     (erlang-skel-separator-end 2)
;;     "composite_refac(_Args) -> []." n>
;;     n
;;     (erlang-skel-double-separator-start 3)
;;     "%%% Internal functions" n
;;     (erlang-skel-double-separator-end 3)
;;     )
;;   "*The template of a gen_refac.
;; Please see the function `tempo-define-template'.")


;; (defvar gen_composite_refac_menu_items
;; `(("Batch Inline Vars" refac_batch_inline_vars)
;;  ("Batch Clone Elimination" refac_batch_clone_elimination)
;;  ("Batch Prefix Module" refac_batch_prefix_module)
;; ))

;; (defvar gen_refac_menu_items
;; `(("Swap Function Arguments" refac_swap_function_arguments)
;; ("Specialise A Function" refac_specialise_a_function)
;; ("Remove An Import Attribute" refac_remove_an_import_attribute)
;; ("Remove An Argument" refac_remove_an_argument)
;; ("Keysearch To Keyfind" refac_keysearch_to_keyfind)
;; ("Apply To Remote Call" refac_apply_to_remote_call)
;; ("Add To Export" refac_add_to_export)
;; ("Add An Import Attribute" refac_add_an_import_attribute)
;; ))


;; (defun refac_batch_inline_vars()
;;   (interactive)
;;   (apply-composite-refac 'refac_batch_inline_vars))


;; (defun refac_batch_clone_elimination()
;;   (interactive)
;;   (apply-composite-refac 'refac_batch_clone_elimination))

;; (defun refac_batch_prefix_module()
;;   (interactive)
;;   (apply-composite-refac 'refac_batch_prefix_module))

;; (defun refac_swap_function_arguments()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_swap_function_arguments))


;; (defun refac_specialise_a_function()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_specialise_a_function))


;; (defun refac_remove_an_import_attribute()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_remove_an_import_attribute))


;; (defun refac_remove_an_argument()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_remove_an_argument))


;; (defun refac_keysearch_to_keyfind()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_keysearch_to_keyfind))


;; (defun refac_apply_to_remote_call()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_apply_to_remote_call))


;; (defun refac_add_to_export()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_add_to_export))


;; (defun refac_add_an_import_attribute()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_add_an_import_attribute))


;; (defvar gen_composite_refac_menu_items
;; `(("Batch Inline Vars" refac_batch_inline_vars)
;; ("Batch Prefix Module" refac_batch_prefix_module)
;; ("Batch Clone Elimination" refac_batch_clone_elimination)
;; ))

;; (defvar gen_refac_menu_items
;; `(("Apply To Remote Call" refac_apply_to_remote_call)
;; ("Swap Function Arguments" refac_swap_function_arguments)
;; ("Add An Import Attribute" refac_add_an_import_attribute)
;; ("Specialise A Function" refac_specialise_a_function)
;; ("Remove An Import Attribute" refac_remove_an_import_attribute)
;; ("Add To Export" refac_add_to_export)
;; ("Remove An Argument" refac_remove_an_argument)
;; ))


;; (defun refac_batch_inline_vars()
;;   (interactive)
;;   (apply-composite-refac 'refac_batch_inline_vars))


;; (defun refac_batch_prefix_module()
;;   (interactive)
;;   (apply-composite-refac 'refac_batch_prefix_module))


;; (defun refac_batch_clone_elimination()
;;   (interactive)
;;   (apply-composite-refac 'refac_batch_clone_elimination))


;; (defun refac_apply_to_remote_call()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_apply_to_remote_call))


;; (defun refac_swap_function_arguments()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_swap_function_arguments))


;; (defun refac_add_an_import_attribute()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_add_an_import_attribute))


;; (defun refac_specialise_a_function()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_specialise_a_function))


;; (defun refac_remove_an_import_attribute()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_remove_an_import_attribute))


;; (defun refac_add_to_export()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_add_to_export))


;; (defun refac_remove_an_argument()
;;   (interactive)
;;   (apply-adhoc-refac 'refac_remove_an_argument))


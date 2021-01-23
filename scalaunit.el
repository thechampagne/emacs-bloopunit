;;; scalaunit.el --- `Scala test' runner -*- lexical-binding: t -*-

;; Copyright (C) 2021 Manfred Bergmann.

;; Author: Manfred Bergmann <manfred.bergmann@me.com>
;; URL: http://github.com/mdbergmann/scalaunit
;; Version: 0.1
;; Keywords: processes scala bloop test
;; Package-Requires: ((emacs "24.3"))

;; This program is free software: you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Provides commands to run test cases in a Scala Bloop project.

;;; Code:

(require 'ansi-color)

(make-variable-buffer-local
 (defvar scalaunit-mode))

(make-variable-buffer-local
 (defvar bloop-project nil))

(make-variable-buffer-local
 (defvar test-kind 'scalatest))

(defvar *scalaunit-output-buf-name* "scalaunit output")

(defun scalaunit--find-test-class ()
  "Generate the package for the test run. This is usually the full designated class."
  (let* ((buffer-text (buffer-substring-no-properties 1 (point-max)))
         (package-string (progn
                           (string-match "^package[ ]+\\(.+\\).*$"
                                         buffer-text)
                           (match-string 1 buffer-text)))
         (clazz-string (progn
                         (string-match "^class[ ]+\\(\\w+\\)[ ]+extends"
                                       buffer-text)
                         (match-string 1 buffer-text))))
    (message "Package: %s" package-string)
    (message "Class: %s" clazz-string)
    (format "%s.%s" package-string clazz-string)
    ))

(defun scalaunit--project-root-dir ()
  "Return the project root directory."
  (locate-dominating-file default-directory ".bloop"))

(defun scalaunit--execute-test-in-context ()
  "Call specific test."
  (let* ((test-cmd-args (list "bloop" "test" bloop-project "--only" (scalaunit--find-test-class)))
         (call-args
          (append (list (car test-cmd-args) nil *scalaunit-output-buf-name* t)
                  (cdr test-cmd-args))))
    (message "calling: %s" call-args)
    (let* ((default-directory (scalaunit--project-root-dir))
           (call-result (apply 'call-process call-args)))
      (message "cwd: %s" default-directory)
      (message "test call result: %s" call-result)
      call-result)))

(defun scalaunit--execute-project-tests ()
  "Run project test. This is async as it might take longer."
  (let* ((test-cmd-args (list "bloop" "test" bloop-project))
         (call-args
          (append (list (car test-cmd-args) *scalaunit-output-buf-name*)
                  test-cmd-args)))
    (message "calling: %s" call-args)
    (let* ((default-directory (scalaunit--project-root-dir))
           (proc (apply 'start-process call-args)))
      (message "cwd: %s" default-directory)
      (message "Process: %s" proc))))

(defun scalaunit--handle-successful-test-result ()
  "Do some stuff when the test ran OK."
  (message "%s" (propertize "Tests OK" 'face '(:foreground "green"))))

(defun scalaunit--handle-unsuccessful-test-result ()
  "Do some stuff when the test ran NOK."
  (message "%s" (propertize "Tests failed!" 'face '(:foreground "red"))))

(defun scalaunit--run-with-context ()
  "Run test in context, being class, or test method."
  (let ((test-result (scalaunit--execute-test-in-context)))
    (when test-result
      (if (= test-result 0)
          (scalaunit--handle-successful-test-result)
        (scalaunit--handle-unsuccessful-test-result))
      (with-current-buffer *scalaunit-output-buf-name*
        (ansi-color-apply-on-region (point-min) (point-max))))))

(defun scalaunit--run-w/o-context ()
  "Run test without context, only on project."
  (scalaunit--execute-project-tests))

(defun scalaunit--run-test (with-context)
  "Execute the test.
WITH-CONTEXT should be `T' to run the test context sensitive,
and should be nil to run all tests of the set project."
  (message "scalaunit: run-test, with-context: %s" with-context)

  (unless (string-equal "scala-mode" major-mode)
    (message "Need 'scala-mode' to run!")
    (return-from 'scalaunit--run-test))
  
  ;; create output buffer if it doesn't exist
  (get-buffer-create *scalaunit-output-buf-name*)

  ;; delete output buffer contents
  (with-current-buffer *scalaunit-output-buf-name*
    (erase-buffer))

  (if with-context
      (scalaunit--run-with-context)
    (scalaunit--run-w/o-context)))
      
(defun scalaunit-run-with-context ()
  "Save buffers and execute command to run the test."
  (interactive)
  (save-buffer)
  (save-some-buffers)
  (scalaunit--run-test t))

(defun scalaunit-run-project-tests ()
  "Save buffers and run all tests in project."
  (interactive)
  (save-buffer)
  (save-some-buffers)
  (scalaunit--run-test nil))

(defun scalaunit-set-project ()
  "Prompts for the Bloop project."
  (interactive)
  (setq bloop-project (completing-read "[scalaunit] Bloop project: "
                                       '())))

(define-minor-mode scalaunit-mode
  "Scala unit - test runner. Runs a command that runs tests."
  :lighter " ScalaUnit"
  :keymap (let ((map (make-sparse-keymap)))
            (define-key map (kbd "C-c t") 'scalaunit-run-with-context)
            map))

(provide 'scalaunit)
;;; scalaunit.el ends here

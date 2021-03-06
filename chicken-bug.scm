;;;; chicken-bug.scm - Bug report-generator
;
; Copyright (c) 2008-2009, The Chicken Team
; All rights reserved.
;
; Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following
; conditions are met:
;
;   Redistributions of source code must retain the above copyright notice, this list of conditions and the following
;     disclaimer. 
;   Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following
;     disclaimer in the documentation and/or other materials provided with the distribution. 
;   Neither the name of the author nor the names of its contributors may be used to endorse or promote
;     products derived from this software without specific prior written permission. 
;
; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
; AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR
; CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
; SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
; THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
; OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
; POSSIBILITY OF SUCH DAMAGE.


(require-extension srfi-13 posix tcp data-structures utils extras)


(define-constant +bug-report-file+ "chicken-bug-report.~a-~a-~a")

(define-constant +fallbackdestinations+ 
  "chicken-janitors@nongnu.org\nchicken-hackers@nongnu.org\nchicken-users@nongnu.org")

(define-constant +destination+ "chicken-janitors@nongnu.org")
(define-constant +mxservers+ (list "mx10.gnu.org" "mx20.gnu.org"))
(define-constant +send-tries+ 3)

(define-foreign-variable +cc+ c-string "C_TARGET_CC")
(define-foreign-variable +cxx+ c-string "C_TARGET_CXX")
(define-foreign-variable +c-include-path+ c-string "C_INSTALL_INCLUDE_HOME")

(define (user-id)
  (cond-expand
   ((or mingw32 msvc) "<not available>")
   (else (user-information (current-user-id)))))

(define (collect-info)
  (print "\n--------------------------------------------------\n")
  (print "This is a bug report generated by chicken-bug(1).\n")
  (print "Date:\t" (seconds->string (current-seconds)) "\n\n")
  (printf "User information:\t~s~%~%" (user-id))
  (print "Host information:\n")
  (print "\tmachine type:\t" (machine-type))
  (print "\tsoftware type:\t" (software-type))
  (print "\tsoftware version:\t" (software-version))
  (print "\tbuild platform:\t" (build-platform) "\n")
  (print "CHICKEN version is:\n" (chicken-version #t) "\n")
  (print "Home directory:\t" (chicken-home) "\n")
  (printf "Include path:\t~s~%~%" ##sys#include-pathnames)
  (print "Features:")
  (for-each
   (lambda (lst) 
     (display "\n  ")
     (for-each 
      (lambda (f)
	(printf "~a~a" f (make-string (fxmax 1 (fx- 16 (string-length f))) #\space)) )
      lst) )
   (chop (sort (map keyword->string ##sys#features) string<?) 5))
  (print "\n\nchicken-config.h:\n")
  (with-input-from-file (make-pathname +c-include-path+ "chicken-config.h")
    (lambda ()
      (display (read-all)) ) )
  (newline)
  (when (and (string=? +cc+ "gcc") (feature? 'unix))
    (print "CC seems to be gcc, trying to obtain version...\n")
    (with-input-from-pipe "gcc -v 2>&1"
      (lambda ()
	(display (read-all)))))
  (newline) )

(define (usage code)
  (print #<<EOF
usage: chicken-bug [FILENAME ...]

  -help  -h            show this message
  -to-stdout           write bug report to standard output
  -                    read description from standard input

Generates a bug report file from user input or alternatively
from the contents of files given on the command line.

EOF
) 
  (exit code) )

(define (user-input)
  (when (##sys#tty-port? (current-input-port))
    (print #<<EOF
This is the CHICKEN bug report generator. Please enter a detailed
description of the problem you have encountered and enter CTRL-D (EOF)
once you have finished. Press CTRL-C to abort the program. You can
also pass the description from a file (just abort now and re-invoke
"chicken-bug" with one or more input files given on the command-line)

EOF
) )
  (read-all) )

(define (justify n)
  (let ((s (number->string n)))
    (if (> (string-length s) 1)
	s
	(string-append "0" s))))

(define (main args)
  (let ((msg "")
	(files #f)
	(stdout #f))
    (for-each
     (lambda (arg)
       (cond ((string=? "-" arg) 
	      (set! files #t)
	      (set! msg (string-append msg "\n\nUser input:\n\n" (user-input))) )
	     ((member arg '("--help" "-h" "-help"))
	      (usage 0) )
	     ((string=? "-to-stdout" arg)
	      (set! stdout #t) )
	     (else
	      (set! files #t)
	      (set! msg 
		(string-append
		 msg
		 "\n\nFile added: " arg "\n\n"
		 (read-all arg) ) ) ) ) )
     args)
    (unless files
      (set! msg (string-append msg "\n\n" (user-input))))
    (newline)
    (let* ((lt (seconds->local-time (current-seconds)))
	   (day (vector-ref lt 3))
	   (mon (vector-ref lt 4))
	   (yr (vector-ref lt 5)) )
      (if stdout
	  (begin
	    (print msg)
	    (collect-info))
	  (try-mail
	   +mxservers+
	   (sprintf +bug-report-file+ (+ 1900 yr) (justify mon) (justify day))
	   (mail-headers)
	   (with-output-to-string
	     (lambda ()
	       (print msg)
	       (collect-info))))))))
      ;(let* ((file (sprintf +bug-report-file+ (+ 1900 yr) (justify mon) (justify day)))
	;     (port (if stdout (current-output-port) (open-output-file file))))
	;(with-output-to-port port
	;  (lambda ()
	;    (print msg)
	;    (collect-info) ) )
	;(unless stdout
	;  (close-output-port port)
	;  (print "\nA bug report has been written to `" file "'. Please send it to")
	;  (print "one of the following addresses:\n\n" +destinations+) ) ) ) ) )

(define (try-mail servs fname hdrs msg)
    (if (null? servs)
        (begin
            (with-output-to-file fname
                (lambda () (print msg)))
            (print "\nCould not send mail automatically!\n\nA bug report has been written to `" fname "'.  Please send it to")
            (print "one of the following addresses:\n\n" +fallbackdestinations+))
        (or (send-mail (car servs) msg hdrs fname)
            (try-mail (cdr servs) fname hdrs msg))))

(define (mail-date-str tm)
    (string-append
        (case (vector-ref tm 6)
            ((0) "Sun, ")
            ((1) "Mon, ")
            ((2) "Tue, ")
            ((3) "Wed, ")
            ((4) "Thu, ")
            ((5) "Fri, ")
            ((6) "Sat, "))
        (string-pad (number->string (vector-ref tm 3)) 2 #\0)
        (case (vector-ref tm 4)
            ((0)  " Jan ")
            ((1)  " Feb ")
            ((2)  " Mar ")
            ((3)  " Apr ")
            ((4)  " May ")
            ((5)  " Jun ")
            ((6)  " Jul ")
            ((7)  " Aug ")
            ((8)  " Sep ")
            ((9)  " Oct ")
            ((10) " Nov ")
            ((11) " Dec "))
        (number->string (+ 1900 (vector-ref tm 5)))
        " "
        (string-pad (number->string (vector-ref tm 2)) 2 #\0)
        ":"
        (string-pad (number->string (vector-ref tm 1)) 2 #\0)
        ":"
        (string-pad (number->string (vector-ref tm 0)) 2 #\0)
        " +0000"))

(define (mail-headers)
    (string-append
        "Date: " (mail-date-str (seconds->utc-time (current-seconds))) "\r\n"
        "From: \"chicken-bug user\" <chicken-bug-command@callcc.org>\r\n"
        "To: \"Chicken Janitors\" <chicken-janitors@nongnu.org>\r\n"
        "Subject: Automated chicken-bug output -- "))

(define (mail-read i o)
    (let ((v   (condition-case (read-line i)
                   (var () (close-input-port i) (close-output-port o) #f))))
        (if v
            (if (char-numeric? (string-ref v 0))
                (string->number (substring v 0 3))
                (mail-read i o))
            #f)))

(define (mail-write i o m)
    (let ((v   (condition-case (display m o)
                   (var () (close-input-port i) (close-output-port o) #f))))
        (if v
            (mail-read i o)
            #f)))

(define (mail-check i o v e k)
    (if (and v (= v e))
        #t
        (begin
            (close-input-port i)
            (close-output-port o)
            (k #f))))

(define (send-mail serv msg hdrs fname)
  (call/cc 
   (lambda (return)
     (do ((try 1 (add1 try)))
	 ((> try +send-tries+))
       (print* "connecting to " serv ", try #" try " ...")
       (receive (i o)
	   (tcp-connect serv 25)
	 (call-with-current-continuation
	  (lambda (k)
	    (mail-check i o (mail-read i o) 220 k)
	    (mail-check i o (mail-write i o "HELO callcc.org\r\n") 250 k)
	    (mail-check i o (mail-write i o "MAIL FROM:<chicken-bug-command@callcc.org>\r\n") 250 k)
	    (mail-check i o (mail-write i o "RCPT TO:<chicken-janitors@nongnu.org>\r\n") 250 k)
	    (mail-check i o (mail-write i o "DATA\r\n") 354 k)
	    (mail-check i o (mail-write i o (string-append hdrs fname "\r\n\r\n" msg "\r\n.\r\n")) 250 k)
	    (display "QUIT" o)
	    (close-input-port i)
	    (close-output-port o)
	    (print "ok.\n\nBug report successfully mailed to the Chicken maintainers.\nThank you very much!\n\n")
	    (return #t))))
       (print " failed.")))))

(main (command-line-arguments))

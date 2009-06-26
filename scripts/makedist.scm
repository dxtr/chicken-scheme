;;;; makedist.scm - Make distribution tarballs


(define *release* #f)

(load-relative "tools.scm")

(set! *verbose* #t)

(define BUILDVERSION (with-input-from-file "buildversion" read))

(define *platform* 
  (let ((sv (symbol->string (software-version))))
    (cond ((string-match ".*bsd" sv) "bsd")
	  (else
	   (case (build-platform)
	     ((mingw32) 
	      (if (string=? (getenv "MSYSTEM") "MINGW32")
		  "mingw-msys"
		  "mingw32"))
	     ((msvc) "msvc")
	     (else sv))))))

(define *make* "make")

(define (release full?)
  (let* ((files (read-lines "distribution/manifest"))
	 (distname (conc "chicken-" BUILDVERSION)) 
	 (distfiles (map (cut prefix distname <>) files)) 
	 (tgz (conc distname ".tar.gz")))
    (run (rm -fr ,distname ,tgz))
    (create-directory distname)
    (for-each
     (lambda (d)
       (let ((d (path distname d)))
	 (unless (file-exists? d)
	   (print "creating " d)
	   (create-directory d))))
     (delete-duplicates (filter-map prefix files) string=?))
    (let ((missing '()))
      (for-each
       (lambda (f)
	 (if (-e f)
	     (run (cp -p ,(qs f) ,(qs (path distname f))))
	     (set! f (cons f missing))))
       files)
      (unless (null? missing)
	(warning "files missing" missing) ) )
    (run (tar cfz ,(conc distname ".tar.gz") ,distname))
    (run (rm -fr ,distname)) ) )

(define (make-html)
  (unless (file-exists? "html")
    (create-directory "html"))
  (for-each
   (lambda (f)
     (run (,(or (get-environment-variable "CSI") "csi") -s scripts/wiki2html.scm
	   html ,f)))
   (directory "manual")))

(define *makeargs*
  (simple-args
   (command-line-arguments)
   (lambda _
     (print "usage: makedist [--release] [--make=PROGRAM] [--platform=PLATFORM] MAKEOPTION ...")
     (exit 1))) )

(run (,*make* -f ,(conc "Makefile." *platform*) distfiles ,@*makeargs*))

(make-html)
(run (cp misc/manual.css html))

(release *release*)

;;;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp; indent-tabs-mode: nil -*-
;;;
;;; --- Zeta streams classes.
;;;

(in-package :io.zeta-streams)

;;;; Types

(deftype ub8  () '(unsigned-byte 8))
(deftype ub16 () '(unsigned-byte 16))
(deftype ub32 () '(unsigned-byte 32))
(deftype sb8  () '(signed-byte 8))
(deftype sb16 () '(signed-byte 16))
(deftype sb32 () '(signed-byte 32))

(deftype ub8-sarray (&optional (size '*))
  `(simple-array ub8 (,size)))

(deftype ub8-vector () '(vector ub8))

(deftype ub16-sarray (&optional (size '*))
  `(simple-array ub16 (,size)))

;;;; Buffers

;;; almost 128 MB: large enough for a stream buffer,
;;; but small enough to fit into a fixnum
(deftype iobuf-index () '(unsigned-byte 27))
(deftype iobuf-length () '(integer 0 #.(expt 2 27)))

(deftype iobuf-buffer () '(simple-array ub8 (*)))

(defstruct (iobuf (:constructor %make-iobuf ()))
  (data (make-array 0 :element-type 'ub8)
        :type iobuf-buffer)
  (size 0 :type iobuf-length)
  (start 0 :type iobuf-index)
  (end 0 :type iobuf-index))

;;;; Stream Classes

(deftype stream-position () '(unsigned-byte 64))

(defclass zeta-stream () ())

(defclass single-channel-zeta-stream (zeta-stream)
  ())

(defclass dual-channel-zeta-stream (zeta-stream)
  ())

(defclass memory-buffer-zeta-stream (zeta-stream)
  ())
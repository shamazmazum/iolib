;; -*- Mode: Lisp; Syntax: ANSI-Common-Lisp -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;   Copyright (C) 2006 by Stelian Ionescu                                 ;
;                                                                         ;
;   This program is free software; you can redistribute it and/or modify  ;
;   it under the terms of the GNU General Public License as published by  ;
;   the Free Software Foundation; either version 2 of the License, or     ;
;   (at your option) any later version.                                   ;
;                                                                         ;
;   This program is distributed in the hope that it will be useful,       ;
;   but WITHOUT ANY WARRANTY; without even the implied warranty of        ;
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         ;
;   GNU General Public License for more details.                          ;
;                                                                         ;
;   You should have received a copy of the GNU General Public License     ;
;   along with this program; if not, write to the                         ;
;   Free Software Foundation, Inc.,                                       ;
;   51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA              ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; (declaim (optimize (speed 2) (safety 2) (space 1) (debug 2)))
(declaim (optimize (speed 0) (safety 2) (space 0) (debug 2)))

(in-package :io.multiplex)

(defclass epoll-multiplex-interface (multiplex-interface)
  ((epoll-fd :reader epoll-fd)))

(defconstant +epoll-priority+ 1)

(define-iomux-interface epoll-multiplex-interface +epoll-priority+)

(defconstant +epoll-default-size-hint+ 25)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defvar *epoll-max-events* 200))

(defmethod initialize-instance :after ((interface epoll-multiplex-interface)
                                       &key (size +epoll-default-size-hint+))
  (let ((epoll-fd (et:epoll-create size)))
    (setf (slot-value interface 'epoll-fd) epoll-fd)
    (finalize-object-closing-fd interface epoll-fd)))

(defmethod monitor-fd progn ((interface epoll-multiplex-interface) handler)
  (let ((flags (logior (if (handler-read-func handler) et:epollin 0)
                       (if (handler-write-func handler) et:epollout 0)
                       (if (handler-except-func handler) et:epollpri 0)))
        (fd (handler-fd handler)))
    (with-foreign-object (ev 'et:epoll-event)
      (et:memset ev 0 #.(foreign-type-size 'et:epoll-event))
      (setf (foreign-slot-value ev 'et:epoll-event 'et:events) flags)
      (setf (foreign-slot-value (foreign-slot-value ev 'et:epoll-event 'et:data)
                                'et:epoll-data 'et:fd)
            fd)
      (et:epoll-ctl (epoll-fd interface) et:epoll-ctl-add fd ev))
    (values interface)))

(defmethod modify-fd progn ((interface epoll-multiplex-interface) fd
                            &key read-handler write-handler except-handler)
  (let ((flags (logior (if read-handler et:epollin 0)
                       (if write-handler et:epollout 0)
                       (if except-handler et:epollpri 0))))
    (with-foreign-object (ev 'et:epoll-event)
      (et:memset ev 0 #.(foreign-type-size 'et:epoll-event))
      (setf (foreign-slot-value ev 'et:epoll-event 'et:events) flags)
      (setf (foreign-slot-value (foreign-slot-value ev 'et:epoll-event 'et:data)
                                'et:epoll-data 'et:fd)
            fd)
      (et:epoll-ctl (epoll-fd interface) et:epoll-ctl-mod fd ev))
    (values interface)))

(defmethod unmonitor-fd progn ((interface epoll-multiplex-interface) handler)
  (et:epoll-ctl (epoll-fd interface)
                et:epoll-ctl-del
                (handler-fd handler)
                (null-pointer))
  (values interface))

(defun epoll-serve-single-fd (handler events)
  (let ((except-func (handler-except-func handler))
        (read-func (handler-read-func handler))
        (write-func (handler-write-func handler))
        (fd (handler-fd handler)))
    (when (and except-func (plusp (logand et:epollerr events)))
      (funcall except-func fd :error))
    (when (and except-func (plusp (logand et:epollpri events)))
      (funcall except-func fd :except))
    (when (and read-func (plusp (logand et:epollin events)))
      (funcall read-func fd :read))
    (when (and write-func (plusp (logand et:epollout events)))
      (funcall write-func fd :write))))

(defmethod serve-fd-events ((interface epoll-multiplex-interface) &key)
  (with-foreign-object (events 'et:epoll-event #.*epoll-max-events*)
    (et:memset events 0 #.(* *epoll-max-events* (foreign-type-size 'et:epoll-event)))
    (let ((ready-fds
           (et:epoll-wait (epoll-fd interface) events
                          #.*epoll-max-events* -1)))
      (loop
         :for i :below ready-fds
         :for fd := (foreign-slot-value (foreign-slot-value (mem-aref events 'et:epoll-event i)
                                                            'et:epoll-event 'et:data)
                                        'et:epoll-data 'et:fd)
         :for event-mask := (foreign-slot-value (mem-aref events 'et:epoll-event i)
                                                'et:epoll-event 'et:events)
         :do (epoll-serve-single-fd (fd-handler interface fd)
                                    event-mask))))
  (values interface))

(defmethod close-multiplex-interface ((interface epoll-multiplex-interface))
  (cancel-finalization interface)
  (et:close (epoll-fd interface)))

;;; wangyi-music.el --- wangyi music mode
;; Time-stamp: <2018-12-07 17:13:06 Friday by lli>

;; Copyright (C) 2013 zhengyu li
;;
;; Author: zhengyu li <lizhengyu419@gmail.com>
;; Keywords: wangyi

;; version: 1.1

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Put this file into your load-path and the following into your ~/.emacs:
;;
;; Installation:
;; add the following lines into your configuration file
;;
;;   (autoload 'wangyi-music "wangyi-music" nil t)

;; 2016-04-03: zhengyu li <lizhengyu419@gmail.com>
;;   the first version
;;
;;; Code:

(require 'json)
(require 'assoc)
(require 'url-http)

(defgroup wangyi-music nil
  "Wangyi music group"
  :group 'entertainment)

;; Customizable variables
(defcustom wangyi-music-cache-directory "~/.emacs.d/wangyi-music/"
  "Wangyi music default cache directory."
  :type 'string
  :group 'wangyi-music)

(defcustom wangyi-music-default-channel 3
  "Wangyi music default channel."
  :type 'number
  :group 'wangyi-music)

(defcustom wangyi-music-player "mplayer"
  "Wangyi music music player."
  :type 'string
  :group 'wangyi-music)

(defcustom wangyi-music-display-album t
  "Wangyi music display album picture."
  :type 'boolean
  :group 'wangyi-music)

;; Faces
(defface wangyi-music-track-face0
  '((t (:height 1.1 :foreground "Grey70")))
  "Wangyi music track face0"
  :group 'wangyi-music)

(defface wangyi-music-track-face1
  '((t (:height 1.05 :foreground "Grey40")))
  "Wangyi music track face1"
  :group 'wangyi-music)

(defface wangyi-music-tag-face
  '((t (:height 1.05 :foreground "Steelblue1")))
  "Wangyi music tag face"
  :group 'wangyi-music)

(defface wangyi-music-title-face
  '((t (:height 1.05 :foreground "Grey65")))
  "Wangyi music title face"
  :group 'wangyi-music)

(defface wangyi-music-album-face
  '((t (:foreground "Red3")))
  "Wangyi music album face"
  :group 'wangyi-music)

(defface wangyi-music-artist-face
  '((t (:foreground "RoyalBlue")))
  "Wangyi music artist face"
  :group 'wangyi-music)

(defface wangyi-music-company-face
  '((t (:foreground "Yellow")))
  "Wangyi music publish company face"
  :group 'wangyi-music)

;; Constant variables
(defconst wangyi-music-channels-delimiter
  (make-string 140 61)
  "Wangyi music channels delimiter.")

(defconst wangyi-music-indent0
  (make-string 1 32)
  "Wangyi music 0-level indentation.")

(defconst wangyi-music-indent1
  (make-string 2 32)
  "Wangyi music 1-level indentation.")

(defconst wangyi-music-indent2
  (make-string 4 32)
  "Wangyi music 2-level indentation.")

(defconst wangyi-music-indent3
  (make-string 5 32)
  "Wangyi music 3-level indentation.")

(defconst wangyi-music-indent4
  (make-string 10 32)
  "Wangyi music 4-level indentation.")

(defconst wangyi-music-buffer-name
  "Wangyi Music"
  "Wangyi music buffer name.")

(defconst wangyi-music-discover-toplist-url
  "http://music.163.com/discover/toplist"
  "Wangyi music get song list url.")

(defconst wangyi-music-get-song-list-detail-url
  "http://music.163.com/api/song/detail"
  "Wangyi music get song list detail url.")

(defconst wangyi-music-song-outer-url
  "http://music.163.com/song/media/outer/url"
  "Wangyi music song outer url")

;; Internal variables
(defvar wangyi-music-mode-map nil
  "Mangyi music mode keymap.")
(defvar wangyi-music-channels nil
  "Wangyi music total channels.")
(defvar wangyi-music-current-channel nil
  "Wangyi music current channel.")
(defvar wangyi-music-song-list nil
  "Wangyi music song list of current channel.")
(defvar wangyi-music-current-song nil
  "Wangyi music current song.")
(defvar wangyi-music-status nil
  "Wangyi music status.")
(defvar wangyi-music-process nil
  "Wangyi music run process.")

(defun init-wangyi-music-mode-map ()
  "Init wangyi music mode key map."
  (setq wangyi-music-mode-map
        (let ((map (make-sparse-keymap)))
          (define-key map (kbd "RET") 'wangyi-music-goto-current-playing)
          (define-key map "s" 'wangyi-music-stop)
          (define-key map "g" 'wangyi-music-refresh)
          (define-key map "j" 'wangyi-music-current-song-info)
          (define-key map "c" 'wangyi-music-set-channel)
          (define-key map "n" 'wangyi-music-play-next-refresh)
          (define-key map "p" 'wangyi-music-play-previous)
          (define-key map "q" 'wangyi-music-bury-buffer)
          (define-key map "x" 'wangyi-music-quit)
          (define-key map " " 'wangyi-music-pause/resume)
          (define-key map "<" 'wangyi-music-seek-backward)
          (define-key map ">" 'wangyi-music-seek-forward)
          map))
  (use-local-map wangyi-music-mode-map))

(defun wangyi-music-pause/resume ()
  "Toggle wangyi music."
  (interactive)
  (if (string-match wangyi-music-status "playing")
      (progn
        (setq wangyi-music-status "paused")
        (process-send-string wangyi-music-process "pause\n"))
    (if (string-match wangyi-music-status "paused")
        (progn
          (setq wangyi-music-status "playing")
          (process-send-string wangyi-music-process "pause\n")))))

(defun wangyi-music-seek-forward ()
  "Seek forward wangyi music."
  (interactive)
  (process-send-string wangyi-music-process "seek 2\n"))

(defun wangyi-music-seek-backward ()
  "Seek backward wangyi music."
  (interactive)
  (process-send-string wangyi-music-process "seek -2\n"))

(defun wangyi-music-stop ()
  "Stop wangyi music."
  (interactive)
  (wangyi-music-kill-process)
  (setq wangyi-music-status "stopped"))

(defun wangyi-music-refresh ()
  "Refresh wangyi music."
  (interactive)
  (wangyi-music-get-song-list-async #'(lambda ()
                                        (wangyi-music-kill-process)
                                        (wangyi-music-play))))

(defun wangyi-music-goto-current-playing ()
  "Go to current playing item of wangyi music."
  (interactive)
  (if (string-match wangyi-music-status "playing")
      (progn
        (goto-char (point-min))
        (search-forward (format "Current song"))
        (goto-char (line-end-position)))
    (if (string-match wangyi-music-status "stopped")
        (wangyi-music-play)
      (if (string-match wangyi-music-status "paused")
          (wangyi-music-pause/resume)
        (error "Unknown status")))))

(defun wangyi-music-set-channel (channel-number)
  "Change wangyi channel with CHANNEL-NUMBER."
  (interactive "nChannel number:")
  (if (<= channel-number (length wangyi-music-channels))
      (progn
        (setq wangyi-music-current-channel channel-number)
        (message (format "Change to channel: %s"
                         (car (elt wangyi-music-channels channel-number))))
        (wangyi-music-refresh))
    (message "Warnning: not exist channel")))

(defun wangyi-music-play-next-refresh ()
  "Play next song and refresh."
  (interactive)
  (let ((previous-song wangyi-music-current-song))
    (wangyi-music-kill-process)
    (wangyi-music-get-next-song)
    (if (>= previous-song wangyi-music-current-song)
        (wangyi-music-refresh)
      (wangyi-music-play))))

(defun wangyi-music-play-previous ()
  "Play previous song."
  (interactive)
  (wangyi-music-kill-process)
  (wangyi-music-get-previous-song)
  (wangyi-music-play))

(defun wangyi-music-current-song-info ()
  "Show current song info."
  (interactive)
  (goto-char (point-min))
  (search-forward (format "Track%2d" wangyi-music-current-song)))

(defun wangyi-music-bury-buffer ()
  "Bury wangyi music buffer."
  (interactive)
  (when (eq major-mode 'wangyi-music-mode)
    (if (fboundp 'quit-window)
        (quit-window)
      (bury-buffer))))

(defun wangyi-music-quit ()
  "Quit wangyi music mode."
  (interactive)
  (when (eq major-mode 'wangyi-music-mode)
    (wangyi-music-stop)
    (kill-buffer (current-buffer))))

(defun wangyi-music-process-live-p (process)
  "Check wangyi music PROCESS is alive."
  (memq (process-status process)
        '(run open listen connect stop)))

(defun wangyi-music-play ()
  "Wangyi music play entry."
  (unless (and wangyi-music-process
               (wangyi-music-process-live-p wangyi-music-process))
    (let (song)
      (setq song (elt wangyi-music-song-list
                      wangyi-music-current-song))
      (wangyi-music-interface-update)
      (setq wangyi-music-process
            (start-process "wangyi-music-proc"
                           nil
                           wangyi-music-player
                           (if (string-match wangyi-music-player "mplayer")
                               "-slave"
                             "")
                           (concat wangyi-music-song-outer-url
                                   (format "?id=%s" (aget song 'id t)))))
      (set-process-sentinel
       wangyi-music-process
       'wangyi-music-proc-sentinel)
      (setq wangyi-music-status "playing"))))

(defun wangyi-music-proc-sentinel (proc change)
  "Wangyi music process sentinel for PROC with CHANGE."
  (when (string-match "\\(finished\\|Exiting\\)" change)
    (wangyi-music-play-next-refresh)))

(defun wangyi-music-get-previous-song ()
  "Get previous song."
  (if (null wangyi-music-song-list)
      (error "Song list is null")
    (setq wangyi-music-current-song (mod (- wangyi-music-current-song 1)
                                         (length wangyi-music-song-list)))))

(defun wangyi-music-get-next-song ()
  "Get next song."
  (if (null wangyi-music-song-list)
      (error "Song list is null")
    (setq wangyi-music-current-song (mod (+ wangyi-music-current-song 1)
                                         (length wangyi-music-song-list)))))
(defun wangyi-music-kill-process ()
  "Kill current song."
  (when (and wangyi-music-process
             (wangyi-music-process-live-p wangyi-music-process))
    (delete-process wangyi-music-process)
    (setq wangyi-music-process nil)))

(defun wangyi-music-get-channels ()
  "Get song list from wangyi music server."
  (setq wangyi-music-channels
        (wangyi-music-parse-channels
         (wangyi-music-send-url wangyi-music-discover-toplist-url))))

(defun wangyi-music-parse-channels (channels-buffer)
  "Parse and get song list from CHANNELS-BUFFER."
  (let (channels-page
        matched-position
        channel-id
        channel-name
        (channels ()))
    (setq buffer-file-coding-system 'no-conversion)
    (with-current-buffer channels-buffer
      (setq channels-page (decode-coding-string
                           (buffer-substring-no-properties (point-min) (point-max))
                           'utf-8))
      (while (string-match "<li data-res-id=\"\\([0-9]\\{5,10\\}\\)\"" channels-page)
        (setq channel-id (match-string 1 channels-page))
        (setq matched-position (string-match "alt=\"\\(.+\\)\"/>" channels-page))
        (setq channel-name (match-string 1 channels-page))
        (setq channels (cons (cons (decode-coding-string channel-name 'utf-8) channel-id) channels))
        (setq channels-page (substring channels-page (+ matched-position 15) -1)))
      (reverse channels))))

(defun wangyi-music-get-song-list ()
  "Get song list from wangyi music server."
  (let ()
    (wangyi-music-parse-song-list
     (wangyi-music-send-url (concat wangyi-music-discover-toplist-url
                                    "?id="
                                    (cdr (elt wangyi-music-channels wangyi-music-current-channel)))))))

(defun wangyi-music-get-song-list-async (callback)
  "Get song list from wangyi music server with CALLBACK."
  (let ()
    (wangyi-music-send-url (concat wangyi-music-discover-toplist-url
                                   "?id="
                                   (cdr (elt wangyi-music-channels wangyi-music-current-channel)))
                           nil
                           #'(lambda (status &rest args)
                               (wangyi-music-parse-song-list (current-buffer))
                               (funcall (car args)))
                           (list callback))))

(defun wangyi-music-parse-song-list (song-list-buffer)
  "Parse and get song list from SONG-LIST-BUFFER."
  (let (song-list-page
        matched-position
        (song-list "["))
    (setq buffer-file-coding-system 'no-conversion)
    (with-current-buffer song-list-buffer
      (setq song-list-page (decode-coding-string
                            (buffer-substring-no-properties (point-min) (point-max))
                            'utf-8))
      (while (setq matched-position (string-match "><a href=\"/song\\?id=\\([0-9]\\{5,10\\}\\)" song-list-page))
        (if (equal song-list "[")
            (setq song-list (concat song-list (match-string 1 song-list-page)))
          (setq song-list (concat song-list "," (match-string 1 song-list-page))))
        (setq song-list-page (substring song-list-page (+ matched-position 15) -1)))
      (setq song-list (concat song-list "]")))

    (wangyi-music-parse-song-list-detail
     (wangyi-music-send-url (concat wangyi-music-get-song-list-detail-url
                                    "?ids="
                                    song-list)))
    (setq wangyi-music-current-song 0)))

(defun wangyi-music-parse-song-list-detail (song-list-detail-buffer)
  "Parse and get song list detail info from SONG-LIST-DETAIL-BUFFER."
  (let (json-begin json-end json-data)
    (setq buffer-file-coding-system 'no-conversion)
    (with-current-buffer song-list-detail-buffer
      (goto-char (point-min))
      (if (not (search-forward "songs"))
          (message "get channels failed")
        (setq json-begin (line-beginning-position))
        (setq json-end (line-end-position))
        (setq json-data (json-read-from-string
                         (decode-coding-string
                          (buffer-substring-no-properties json-begin json-end)
                          'utf-8)))))
    (wangyi-music-filter-song-list-detail
     (cdr (assoc 'songs json-data)))))

(defun wangyi-music-filter-song-list-detail (song-list-detail)
  "Filter invalid song from SONG-LIST-DETAIL."
  (dotimes (i (length song-list-detail))
    (setq wangyi-music-song-list
          (cons (elt song-list-detail i) wangyi-music-song-list)))
  (setq wangyi-music-song-list (reverse wangyi-music-song-list)))

(defun wangyi-music-insert-image-async (url insert-buffer insert-point)
  "Insert album image async with URL, INSERT-BUFFER and INSERT-POINT."
  (wangyi-music-send-url
   url
   nil
   #'(lambda (status &rest args)
       (let ((insert-buffer (elt args 0))
             (insert-point (elt args 1))
             (insert-image nil)
             (end nil))
         (setq buffer-file-coding-system 'no-conversion)
         (goto-char (point-min))
         (setq end (search-forward "\n\n" nil t))
         (when end
           (delete-region (point-min) end)
           (setq image-to-insert (buffer-substring (point-min) (point-max))))
         (kill-buffer)
         (with-current-buffer insert-buffer
           (save-excursion
             (let ((buffer-read-only nil))
               (condition-case err
                   (let ((img (progn
                                (clear-image-cache t)
                                (create-image image-to-insert nil t :relief 2 :ascent 'center))))
                     (goto-char insert-point)
                     (insert-image img)
                     img)
                 (error "Insert album picture failed")))))))
   (list insert-buffer insert-point)))

(defun wangyi-music-interface-update ()
  "Update wangyi music mode UI."
  (with-current-buffer wangyi-music-buffer-name
    (let ((buffer-read-only nil))
      (erase-buffer)
      (insert (concat (propertize "网易."
                                  'face '(:height 1.3 :foreground "Grey70"))
                      (propertize "Music"
                                  'face '(:height 1.4 :foreground "ForestGreen"))))
      (insert (propertize "\n\nTotal channels:"
                          'face '(:foreground "Green3" :height 1.1)))
      (insert (propertize (format "\n%s%s"
                                  wangyi-music-indent0
                                  wangyi-music-channels-delimiter)
                          'face '(:foreground "Grey80")))
      (let (channels
            (counter 0)
            (channel-list wangyi-music-channels))
        (while channel-list
          (if (zerop (mod counter 5))
              (progn
                (if (not (zerop counter))
                    (insert channels))
                (setq channels (format "\n%s" wangyi-music-indent0))))
          (setq channels (concat channels (concat (propertize
                                                   (format "%-2d:" counter)
                                                   'face '(:foreground "Green" :height 1.1))
                                                  (propertize (format "%-20s " (caar channel-list))
                                                              'face '(:foreground "Grey80" :height 1.1)))))
          (setq counter (1+ counter))
          (setq channel-list (cdr channel-list)))
        (if (not (string-equal channels (format "\n%s" wangyi-music-indent0)))
            (insert channels))
        (insert (propertize (format "\n%s%s"
                                    wangyi-music-indent0
                                    wangyi-music-channels-delimiter)
                            'face '(:foreground "Grey90"))))
      (insert (concat (propertize "\n\nCurrent channel: "
                                  'face '(:foreground "Green3" :height 1.2))
                      (propertize (format "%s\n\n"
                                          (car (elt wangyi-music-channels wangyi-music-current-channel)))
                                  'face '(:foreground "Orange" :height 1.2))))
      (let (song
            title
            album
            artist
            company
            song-info)
        (setq song (elt wangyi-music-song-list wangyi-music-current-song))
        (if wangyi-music-display-album
            (progn
              (insert wangyi-music-indent2)
              (wangyi-music-insert-image-async (aget (aget song 'album) 'picUrl) (current-buffer) (point))
              (insert "\n\n")))
        (insert (concat (propertize (format "%sPrevious song: "
                                            wangyi-music-indent0)
                                    'face 'wangyi-music-track-face1)
                        (propertize (format "%s "
                                            (aget (elt wangyi-music-song-list
                                                       (mod (- wangyi-music-current-song 1)
                                                            (length wangyi-music-song-list)))
                                                  'name t))
                                    'face 'wangyi-music-track-face1)))
        (insert (concat (propertize (format "\n%sCurrent song: "
                                            wangyi-music-indent0)
                                    'face 'wangyi-music-track-face0)
                        (propertize (format "%s (kbps %s) "
                                            (aget song 'name t)
                                            (aget (aget song 'bMusic t) 'bitrate t))
                                    'face 'wangyi-music-track-face1)))
        (insert (concat (propertize (format "\n%sNext song: "
                                            wangyi-music-indent0)
                                    'face 'wangyi-music-track-face1)
                        (propertize (format "%s "
                                            (aget (elt wangyi-music-song-list
                                                       (mod (+ wangyi-music-current-song 1)
                                                            (length wangyi-music-song-list)))
                                                  'name t))
                                    'face 'wangyi-music-track-face1)))

        (dotimes (i (length wangyi-music-song-list))
          (setq song (elt wangyi-music-song-list i))
          (setq title (aget song 'name t))
          (setq album (aget (aget song 'album t) 'name t))
          (setq company (aget (aget song 'album t) 'company t))
          (setq artist (aget (elt (aget song 'artists t) 0) 'name t))
          (setq song-info (concat (propertize (format "\n\n%sTrack%2d " wangyi-music-indent1 i)
                                              'face 'wangyi-music-track-face0)
                                  (propertize "Title: " 'face 'wangyi-music-tag-face)
                                  (propertize (format "%s\n" title) 'face 'wangyi-music-title-face)
                                  (propertize (format "%sAlbum: "
                                                      wangyi-music-indent4)
                                              'face 'wangyi-music-tag-face)
                                  (propertize (format "%s\n" album)
                                              'face 'wangyi-music-album-face)
                                  (propertize (format "%sArtist: "
                                                      wangyi-music-indent4)
                                              'face 'wangyi-music-tag-face)
                                  (propertize (format "%s\n" artist)
                                              'face 'wangyi-music-artist-face)
                                  (propertize (format "%sCompany: "
                                                      wangyi-music-indent4)
                                              'face 'wangyi-music-tag-face)
                                  (propertize (format "%s" company)
                                              'face 'wangyi-music-company-face)))
          (insert song-info)))
      (set-buffer-modified-p nil)
      (goto-char (point-min))
      (search-forward "Current song")
      (goto-char (line-end-position)))))

(defun wangyi-music-send-url (url &optional url-args callback callback-args)
  "Fetch data from wangyi music server with URL and optional URL-ARGS, CALLBACK and CALLBACK-ARGS."
  (let ((url-cookie-untrusted-urls '(".*"))
        (url-request-method "GET")
        (url-request-extra-headers '(("Host" . "music.163.com")
                                     ("Content-Type" . "application/x-www-form-urlencoded")
                                     ("Accept" . "*/*")
                                     ("Referer" . "http://music.163.com/")
                                     ("Accept-Language" . "en-us"))))
    (if url-args
        (setq url-request-data (mapconcat #'(lambda (arg)
                                              (concat (url-hexify-string (car arg))
                                                      "="
                                                      (url-hexify-string (cdr arg))))
                                          url-args "&")))
    (if callback
        (url-retrieve url callback callback-args)
      (url-retrieve-synchronously url))))

;;;###autoload
(defun wangyi-music ()
  "Play wangyi music in its own buffer."
  (interactive)
  (cond
   ((buffer-live-p (get-buffer wangyi-music-buffer-name))
    (switch-to-buffer wangyi-music-buffer-name))
   (t
    (wangyi-music-mode)
    ;; Init settings
    (setq wangyi-music-status "stopped")
    (setq wangyi-music-current-channel wangyi-music-default-channel)
    (if (not (file-exists-p wangyi-music-cache-directory))
        (mkdir wangyi-music-cache-directory t))
    (init-wangyi-music-mode-map)
    (wangyi-music-get-channels)
    (wangyi-music-get-song-list)
    (wangyi-music-kill-process)
    (wangyi-music-play)
    (select-window (display-buffer (current-buffer)))
    (delete-other-windows))))

(defun wangyi-music-mode ()
  "Major mode for controlling the Wangyi Music buffer."
  (set-buffer
   (get-buffer-create wangyi-music-buffer-name))
  (kill-all-local-variables)
  (setq major-mode 'wangyi-music-mode)
  (setq mode-name "Wangyi-Music")
  (setq truncate-lines t)
  (setq buffer-read-only t)
  (setq buffer-undo-list t)
  (run-hooks 'wangyi-music-mode-hook))

;;; provide features
(provide 'wangyi-music)

;;; wangyi-music.el ends here

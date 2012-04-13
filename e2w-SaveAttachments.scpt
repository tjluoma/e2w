using terms from application "Mail"

	on perform mail action with messages theMessages for rule theRule

		tell application "Mail"

			repeat with oneMessage in theMessages

				set theText to content of oneMessage

				set theSubject to (subject of oneMessage) as Unicode text

				if theSubject is "" then set theSubject to "TheSubjectWasLeftEmpty"

				-- CHANGE this path to yours
				set theFile to ("Users:tjluoma:MailAttachments:") & theSubject & ".txt"


				set theFileID to open for access file theFile with write permission
				write theText to theFileID
				close access theFileID

				set {mail attachment:theAttachments} to oneMessage

				repeat with oneAttachment in mail attachments of oneMessage

					-- CHANGE this path to yours
					save oneAttachment in ("Users:tjluoma:MailAttachments:") & (name of oneAttachment)

				end repeat

			end repeat

		end tell

	end perform mail action with messages

end using terms from


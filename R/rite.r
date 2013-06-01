rite <- function(filename=NULL, catchOutput=FALSE, evalenv=.GlobalEnv,
				fontFamily="Courier", fontSize=10, orientation="horizontal",
				highlight=c("r","latex"), color="purple", ...){	
	# setup some values to deal with load/save/exit
	filename <- filename # script filename (if loaded or saved)
	scriptSaved <- TRUE # a logical for whether current edit file is saved
	searchterm <- ""
	if(is.null(color) || color=="")
		color <- "purple" # syntax highlighting color (functions)
	wmtitle <- packagetitle <- paste("rite ", packageDescription("rite", fields = "Version"), sep="")
	
	# optionally setup evaluation environment
	if(is.null(evalenv)){
		editenv <- new.env()
		evalenv <- editenv
	}
	
	# configure catchOutput/catchError
	if(catchOutput){
		outputSaved <- TRUE # a logical for whether current output file is saved
		#outsink <- textConnection("osink", "w") # create connection for stdout
		#sink(outsink, type="output") # sink stdout
		errsink <- textConnection("esink", "w") # create connection for stderr
		sink(errsink, type="message") # sink stderr
	}
		
	# exit procedure
	exitWiz <- function() {
		if(catchOutput){
			if(!outputSaved){
				exit <- tkmessageBox(message = "Do you want to save the output?", icon = "question", type = "yesnocancel", default = "yes")			
				if(tclvalue(exit)=="yes")
					saveOutput()
				else if(tclvalue(exit)=="no"){}
				else{
					tkfocus(txt_edit)
					return()
				}
			}
		}
		if(!scriptSaved){
			exit <- tkmessageBox(message = "Do you want to save the script?", icon = "question", type = "yesnocancel", default = "yes")			
			if(tclvalue(exit)=="yes")
				saveScript()
			else if(tclvalue(exit)=="no"){}
			else{
				tkfocus(txt_edit)
				return()
			}
		}
		else{
			exit <- tkmessageBox(message = "Are you sure you want to close rite?", icon = "question", type = "yesno", default = "yes")
			if(tclvalue(exit)=="yes"){}
			else if(tclvalue(exit)=="no"){
				tkfocus(txt_edit)
				return()
			}
		}
		if(catchOutput){
			#sink(NULL, type="output")
			#close(outsink)
			sink(NULL, type="message")
			close(errsink)
		}
		tkdestroy(editor)
		bringToTop(-1)
	}
	
	### FILE MENU FUNCTIONS ###
	newScript <- function(){
		if(!scriptSaved){
			exit <- tkmessageBox(message = "Do you want to save the script?", icon = "question", type = "yesnocancel", default = "yes")			
			if(tclvalue(exit)=="yes")
				saveScript()
			else if(tclvalue(exit)=="no"){}
			else{
				tkfocus(txt_edit)
				return()
			}
		}
		tkdelete(txt_edit,"0.0","end")
		filename <<- NULL
		scriptSaved <<- TRUE
		wmtitle <<- packagetitle
		tkwm.title(editor, wmtitle)
	}
	loadScript <- function(filename=filename){
		if(is.null(filename) | is.na(filename) | filename %in% c("","%filename"))
			filename <- tclvalue(tkgetOpenFile())
		if(!length(filename) || filename==""){
			filename <<- filename
			return()
		}
		chn <- tclopen(filename, "r")
		tkinsert(txt_edit, "end", tclvalue(tclread(chn)))
		tclclose(chn)
		scriptSaved <<- TRUE
		wmtitle <<- paste(filename,"-",packagetitle)
		tkwm.title(editor, wmtitle)
	}
	saveScript <- function(){
		if(is.null(filename) || !length(filename) || filename=="")
			saveAsScript()
		else{
			chn <- tclopen(filename, "w")
			tclputs(chn, tclvalue(tkget(txt_edit,"0.0","end")))
			tclclose(chn)
			scriptSaved <<- TRUE
			wmtitle <<- packagetitle
			wmtitle <<- paste(filename,"-",wmtitle)
			tkwm.title(editor, wmtitle)
		}
	}
	saveAsScript <- function() {
		fname <- tclvalue(tkgetSaveFile(initialdir=getwd()))
		if(!length(fname) || fname==""){
			filename <<- ""
			return()
		}
		else{
			chn <- tclopen(fname, "w")
			tclputs(chn, tclvalue(tkget(txt_edit,"0.0","end")))
			tclclose(chn)
			scriptSaved <<- TRUE
			filename <<- fname
			wmtitle <<- packagetitle
			wmtitle <<- paste(fname,"-",wmtitle)
			tkwm.title(editor, wmtitle)
		}
	}	
	includeScript <- function(){
		filename <- tclvalue(tkgetOpenFile())
		if (!length(filename) || filename==""){
			filename <<- filename
			return()
		}
		else{
			chn <- tclopen(filename, "r")
			tkinsert(txt_edit, "insert", tclvalue(tclread(chn)))
			tclclose(chn)
			scriptSaved <<- FALSE
		}
	}
	includeScriptReference <- function(){
		filename <- tclvalue(tkgetOpenFile())
		if (!length(filename) || filename=="")
			return()
		else
			tkinsert(txt_edit, "insert", paste0("sys.source(\"",filename,"\")\n"))
	}
	
	### RUN FUNCTIONS ###
	runCode <- function(code=NULL, e=NULL) {
        if(is.null(e)){
			e <- try(parse(text=code))
			if (inherits(e, "try-error")) {
				tkmessageBox(message="Parse error\nUse F7 to check syntax", icon="error")
				tkfocus(txt_edit)
				return()
			}
		}
        out <- ""
		writeError <- function(errmsg, type, focus=TRUE){
			tkconfigure(err_out, state="normal")
			tkinsert(err_out,"end",paste0(type,": ",errmsg,"\n"))
			tkconfigure(err_out, state="disabled")
			if(focus){
				tkselect(nb2, 1)
				tkfocus(txt_edit)
			}
		}
		if(grepl("library(",e,fixed=TRUE)){
			lib <- try(eval(e[1]))
			if(inherits(lib,"try-error")){
				if(catchOutput)
					writeError(lib,"Error",TRUE)
				else
					print(lib)
			}
			else{
				packagename <- strsplit(strsplit("library(MTurkR)","library(",fixed=TRUE)[[1]][2],")")[[1]][1]
				packs <- c(	packagename,
							gsub(" ","",strsplit(packageDescription(packagename, fields="Depends"),",")[[1]]))
				packs <- na.omit(packs)
				for(i in 1:length(packs)){
					funs <- try(paste0(unique(gsub("<-","",objects(paste0("package:",packagename)))),collapse=" "), silent=TRUE)
					if(!inherits(funs,"try-error"))
						.Tcl(paste0("ctext::addHighlightClass ",.Tk.ID(txt_edit)," ",packagename,"functions ",color,"  [list ",funs," ]"))
				}
			}
			
		}
		else{
			out <- tryCatch({withVisible(eval(e[1], envir=evalenv))},
				error = function(errmsg){
					errmsg <- strsplit(as.character(errmsg),":")[[1]]
					errmsg <- paste(errmsg[length(errmsg)],collapse=":")
					if(length(e)>1){
						errbox <- tkmessageBox(message = paste("Error:",errmsg,"\nDo you want to continue evaluation?"),
												icon = "error", type = "yesno", default = "no")
						if(tclvalue(errbox)=="no")
							e <<- ""
						if(catchOutput)
							writeError(errmsg,"Error",FALSE)
					}
					else if(catchOutput)
						writeError(errmsg,"Error")
					else
						tkmessageBox(message = paste("Error:",errmsg), icon = "error")
					out <<- list(value="", visible=FALSE)
				},
				warning = function(errmsg){
					errmsg <- strsplit(as.character(errmsg),":")[[1]]
					errmsg <- paste(errmsg[length(errmsg)],collapse=":")
					if(length(e)>1){
						errbox <- tkmessageBox(message = paste("Warning:",errmsg,"\nDo you want to continue evaluation?"),
												icon = "warning", type = "yesno", default = "no")
						if(tclvalue(errbox)=="no")
							e <<- ""
						if(catchOutput)
							writeError(errmsg,"Warning",FALSE)
					}
					else if(catchOutput)
						writeError(errmsg,"Warning")
					else
						tkmessageBox(message = paste("Warning:",errmsg), icon = "warning")
				},
				message = function(errmsg){
					errmsg <- strsplit(as.character(errmsg),":")[[1]]
					errmsg <- paste(errmsg[length(errmsg)],collapse=":")
					if(length(e)>1){
						errbox <- tkmessageBox(message = paste("Message:",errmsg,"\nDo you want to continue evaluation?"),
												icon = "info", type = "yesno", default = "no")
						if(tclvalue(errbox)=="no")
							e <<- ""
						if(catchOutput)
							writeError(errmsg,"Message",FALSE)
					}
					else if(catchOutput)
						writeError(errmsg,"Message")
					else
						tkmessageBox(message = paste("Message:",errmsg), icon = "info")
				},
				interrupt = function(){
					if(catchOutput)
						writeError(e[1],"Interruption")
					else
						tkmessageBox(message="Evaluation interrupted!", icon="error")
					out <<- list(value="", visible=FALSE)
				}
			)
			if(catchOutput && out$visible){ # output to `output`
				tkconfigure(output, state="normal")
				tkinsert(output,"end",paste0(capture.output(out$value),"\n",collapse=""))
				tkconfigure(output, state="disabled")
				tkselect(nb2, 0)
				outputSaved <<- FALSE
			}
			else if(length(out)>1 && out$visible)
				print(out$value)	# output to console
		}
		if(length(e)>1)
			runCode(code=code,e=e[2:length(e)])
    }
    runLine <- function(){
		code <- tclvalue(tkget(txt_edit, "insert linestart", "insert lineend"))
		if(!code=="")
			runCode(code)
	}
	runSelection <- function(){
		if(!tclvalue(tktag.ranges(txt_edit,"sel"))=="")
			runCode(tclvalue(tkget(txt_edit,"sel.first","sel.last")))
	}
	runAll <- function()
		runCode(tclvalue(tkget(txt_edit,"1.0","end")))

	### OUTPUT FUNCTIONS ###
	if(catchOutput){
		saveOutput <- function() {
			filename <- tclvalue(tkgetSaveFile(initialdir=getwd()))
			if (!length(filename) || filename=="")
				return()
			chn <- tclopen(filename, "w")
			tclputs(chn, tclvalue(tkget(output,"0.0","end")))
			tclclose(chn)
		}
		clearOutput <- function(){
			tkconfigure(output, state="normal")
			tkdelete(output,"0.0","end")
			tkconfigure(output, state="disabled")
			tkselect(nb2, 0)
		}
		clearError <- function(){
			tkconfigure(err_out, state="normal")
			tkdelete(err_out,"0.0","end")
			tkconfigure(err_out, state="disabled")
			tkselect(nb2, 1)
		}
		
		# convert script to .tex or tangles with knitr
		knittxt <- function(mode="knit"){
			knit_inst <- try(library(knitr), silent=TRUE)
			if(inherits(knit_inst, "try-error")){
				i <- try(install.packages("knitr"), silent=TRUE)
				if(inherits(i, "try-error")){
					tkmessageBox(message="knitr not installed and not installable")
					return()
				}
			}
			ksink1 <- ""
			ksink2 <- ""
			knitsink1 <- textConnection("ksink1", "w") # create connection for stdout
			knitsink2 <- textConnection("ksink2", "w") # create connection for stderr
			sink(knitsink1, type="output") # sink stdout
			sink(knitsink2, type="message") # sink stderr
			if(mode=="knit")
				knit_out <- try(knit(text=tclvalue(tkget(txt_edit,"0.0","end"))), silent=TRUE)
			else if(mode=="sweave"){
				sweave_out <- try(Sweave2knitr(text=tclvalue(tkget(txt_edit,"0.0","end"))), silent=TRUE)
				if(inherits(sweave_out, "try-error")){
					tkmessageBox(message="Could not convert Sweave to knitr")
					return()
				}
				else
					knit_out <- try(knit(text=sweave_out), silent=TRUE)
			}
			else if(mode=="tangle"){
				sweave_out <- try(Sweave2knitr(text=tclvalue(tkget(txt_edit,"0.0","end"))), silent=TRUE)
				if(inherits(sweave_out, "try-error")){
					tkmessageBox(message="Could not convert Sweave to knitr")
					return()
				}
				else
					knit_out <- try(purl(text=sweave_out), silent=TRUE)
			}
			else if(mode=="purl")
				knit_out <- try(purl(text=tclvalue(tkget(txt_edit,"0.0","end"))), silent=TRUE)
			else
				return()
			sink(NULL, type="output")
			sink(NULL, type="message")
			close(knitsink1)
			close(knitsink2)
			tkselect(nb2, 1)
			tkconfigure(err_out, state="normal")
			tkinsert(err_out, "insert", paste0(ksink1,collapse="\n"))
			tkinsert(err_out, "insert", paste0(ksink2,collapse="\n"))
			tkconfigure(err_out, state="disabled")
			sink(errsink, type="message")
			if(inherits(knit_out,"try-error")){
				tkmessageBox(message=paste("knitr failed:\n",knit_out))
				return()
			}
			else{
				clearOutput()
				tkconfigure(output, state="normal")
				tkinsert(output, "insert", knit_out)
				tkconfigure(output, state="disabled")
				tkselect(nb2, 0)
				return()
			}
		}
	}
	pdffromfile <- function(){
		filetopdf <- tclvalue(tkgetOpenFile())
		if(!filetopdf==""){
			clearError()
			tkconfigure(err_out, state="normal")
			tkmark.set(err_out, "insert", "end")
			latex1 <- system(paste("pdflatex",filetopdf), intern=TRUE)
			tkinsert(err_out, "insert", paste0(latex1,collapse="\n"))
			latex2 <- system(paste("bibtex",filetopdf), intern=TRUE)
			tkinsert(err_out, "insert", paste0(latex2,collapse="\n"))
			latex3 <- system(paste("pdflatex",filetopdf), intern=TRUE)
			tkinsert(err_out, "insert", paste0(latex3,collapse="\n"))
			latex4 <- system(paste("pdflatex",filetopdf), intern=TRUE)
			tkinsert(err_out, "insert", paste0(latex4,collapse="\n"))
			tkconfigure(err_out, state="disabled")
			tkselect(nb2, 1)
			if(filetopdf %in% list.files())
				tkmessageBox(message="PDF created!", icon="info")
			else
				tkmessageBox(message="PDF not created!", icon="error")
		}
	}
	
	### HELP MENU FUNCTIONS ###
	addHighlighting <- function(){
		addHighlight <- function(){
			if(!tclvalue(objectval)=="")
				.Tcl(paste0("ctext::addHighlightClass ",.Tk.ID(txt_edit)," functions ",color,"  [list ",tclvalue(objectval)," ]"))
			if(!tclvalue(envirval)=="" && paste0("package:",tclvalue(envirval)) %in% search()){
				packs <- c(	tclvalue(envirval),
							gsub(" ","",strsplit(packageDescription(tclvalue(envirval), fields="Depends"),",")[[1]]))
				packs <- na.omit(packs)
				for(i in 1:length(packs)){
					funs <- try(paste0(unique(gsub("<-","",objects(paste0("package:",tclvalue(envirval))))),collapse=" "), silent=TRUE)
					if(!inherits(funs,"try-error"))
						.Tcl(paste0("ctext::addHighlightClass ",.Tk.ID(txt_edit)," ",tclvalue(envirval),"functions ",color,"  [list ",funs," ]"))
				}
			}
		}
		highlightbox <- tktoplevel()
		tkwm.title(highlightbox, paste("Add Highlighting Class",sep=""))
		tkwm.iconbitmap(highlightbox,system.file("logo", "favicon.ico", package = "rite"))
		r <- 1
		tkgrid.columnconfigure(highlightbox,1,weight=3)
		tkgrid.columnconfigure(highlightbox,2,weight=10)
		tkgrid.columnconfigure(highlightbox,3,weight=3)
		r <- r + 1
		entryform <- tkframe(highlightbox, relief="groove", borderwidth=2)
			# entry fields
			objectval <- tclVar("")
			envirval <- tclVar("")
			obj.entry <- tkentry(entryform, width = 40, textvariable=objectval)
			env.entry <- tkentry(entryform, width = 40, textvariable=envirval)
			# grid
			tkgrid(tklabel(entryform, text = "        "), row=1, column=1)
			tkgrid(tklabel(entryform, text = "Space-separated object(s):   "), row=2, column=1)
			tkgrid(obj.entry, row=2, column=2)
			tkgrid.configure(obj.entry, sticky="ew")
			tkgrid(tklabel(entryform, text = "Attached package (and dependencies):"), row=3, column=1)
			tkgrid(env.entry, row=3, column=2)
			tkgrid.configure(env.entry, sticky="ew")
			tkbind(obj.entry,"<Return>",addHighlight)
			tkgrid(tklabel(entryform, text = "        "), row=4, column=2)
			tkgrid.columnconfigure(entryform,2,weight=10)
			tkgrid.columnconfigure(entryform,3,weight=1)
		tkgrid(entryform, row=r, column=1, columnspan=3)
		tkgrid.configure(entryform, sticky="nsew")
		r <- r + 1
		tkgrid(ttklabel(highlightbox, text= "     "), row=r, column=2)
		r <- r + 1
		buttons <- tkframe(highlightbox)
			tkgrid(tkbutton(buttons, text = "  Add  ", command = addHighlight), row=1, column=1)
			tkgrid(tkbutton(buttons, text = " Close ", command = function(){tkdestroy(highlightbox); tkfocus(txt_edit)}), row=1, column=2)
		tkgrid(buttons, row=r, column=2)
		r <- r + 1
		tkgrid(ttklabel(highlightbox, text= "     "), row=r, column=2)
		tkfocus(obj.entry)
	}
	about <- function(){
		aboutbox <- tktoplevel()
		tkwm.title(aboutbox, paste0("rite Version ", packageDescription("rite", fields = "Version")))
		tkwm.iconbitmap(aboutbox,system.file("logo", "favicon.ico", package = "rite"))
		tkgrid(ttklabel(aboutbox, text= "     "), row=1, column=1)
		tkgrid(ttklabel(aboutbox, text= "     "), row=1, column=3)
		tkgrid(ttklabel(aboutbox, text = paste0("(C) Thomas J. Leeper ",max("2013",format(Sys.Date(),"%Y")))), row=2, column=2)
		tkgrid(ttklabel(aboutbox, text= "     "), row=3, column=2)
		tkgrid(website <- ttklabel(aboutbox, text = "http://www.thomasleeper.com/software.html", foreground="blue"), row=4, column=2)
		tkgrid(ttklabel(aboutbox, text= "     "), row=5, column=2)
		tkgrid(tkbutton(aboutbox, text = "   OK   ", command = function(){tkdestroy(aboutbox); tkfocus(txt_edit)}), row=6, column=2)
		tkgrid(ttklabel(aboutbox, text= "     "), row=7, column=2)
		tkbind(website, "<ButtonPress>", function() browseURL("http://www.thomasleeper.com/software.html"))
		tkfocus(aboutbox)
	}
	
	### EDITOR LAYOUT ###
	editor <- tktoplevel(borderwidth=0)
	tkwm.title(editor, wmtitle)	# title
	tkwm.iconbitmap(editor,system.file("logo", "favicon.ico", package = "rite"))
	tkwm.protocol(editor, "WM_DELETE_WINDOW", exitWiz) # regulate exit

	### EDITOR MENUS ###
	menuTop <- tkmenu(editor)           # Create a menu
	tkconfigure(editor, menu = menuTop) # Add it to the 'editor' window
	menuFile <- tkmenu(menuTop, tearoff = FALSE)
		tkadd(menuFile, "command", label="New Script", command=newScript, underline = 0)
		tkadd(menuFile, "command", label="Load Script", command=loadScript, underline = 0)
		tkadd(menuFile, "command", label="Save Script", command=saveScript, underline = 0)
		tkadd(menuFile, "command", label="SaveAs Script", command=saveAsScript, underline = 1)
		tkadd(menuFile, "command", label="Append Script", command=includeScript, underline = 1)
		tkadd(menuFile, "command", label="Insert Script Reference", command=includeScriptReference, underline = 0)
		tkadd(menuFile, "separator")
		tkadd(menuFile, "command", label="Change dir...", command=function(...){
			tkdir <- tclvalue(tkchooseDirectory())
			if(!tkdir=="")
				setwd(tkdir)
			}, underline = 7)
		tkadd(menuFile, "separator")
		tkadd(menuFile, "command", label = "Close rite", command = exitWiz, underline = 0)
		tkadd(menuFile, "separator")
		tkadd(menuFile, "command", label = "Quit R", command = function() {exitWiz; quit()}, underline = 0)
		tkadd(menuTop, "cascade", label = "File", menu = menuFile, underline = 0)
	menuRun <- tkmenu(menuTop, tearoff = FALSE)
		tkadd(menuRun, "command", label = "Run Line", command = runLine, underline = 4)
		tkadd(menuRun, "command", label = "Run Selection", command = runSelection, underline = 4)
		tkadd(menuRun, "command", label = "Run All", command = runAll, underline = 4)
		#tkadd(menuRun, "separator")
		#tkadd(menuRun, "command", label = "Interrupt", command = function(){pskill(Sys.getpid(),SIGINT) }, underline = 0)
		#tkadd(menuRun, "command", label = "Interrupt", command = function() tkdestroy(txt_edit), underline = 0)
		tkadd(menuTop, "cascade", label = "Run", menu = menuRun, underline = 0)
	if(catchOutput){
		menuOutput <- tkmenu(menuTop, tearoff = FALSE)
			copyOutput <- function(){
				tkconfigure(output, state="normal")
				tkclipboard.clear()
				tkclipboard.append(tclvalue(tkget(output, "0.0", "end")))
				tkconfigure(output, state="disabled")
			}
			tkadd(menuOutput, "command", label = "Copy Output", command = copyOutput, underline = 0)
			tkadd(menuOutput, "command", label = "Save Output", command = saveOutput, underline = 0)
			tkadd(menuOutput, "command", label = "Clear Output Panel", command = clearOutput, underline = 1)
			tkadd(menuOutput, "separator")
			copyMessage <- function(){
				tkconfigure(err_out, state="normal")
				tkclipboard.clear()
				tkclipboard.append(tclvalue(tkget(err_out, "0.0", "end")))
				tkconfigure(err_out, state="disabled")
			}
			tkadd(menuOutput, "command", label = "Copy Message", command = copyMessage, underline = 0)
			tkadd(menuOutput, "command", label = "Clear Message", command = clearError, underline = 1)
			tkadd(menuOutput, "separator")
			menuReport <- tkmenu(menuOutput, tearoff = FALSE)
				tkadd(menuReport, "command", label = "knit", command = function() knittxt(mode="knit"), underline = 0)
				tkadd(menuReport, "command", label = "knit (from Sweave)", command = function() knittxt(mode="sweave"))
				tkadd(menuReport, "command", label = "purl", command = function() knittxt(mode="purl"), underline = 0)
				tkadd(menuReport, "command", label = "purl (from Sweave)", command = function() knittxt(mode="tangle"))
				tkadd(menuReport, "command", label = "pdflatex (from .tex file)", command = pdffromfile)
				tkadd(menuOutput, "cascade", label = "Report Generation", menu = menuReport, underline = 0)		
			tkadd(menuTop, "cascade", label = "Output", menu = menuOutput, underline = 0)
	}
	menuHelp <- tkmenu(menuTop, tearoff = FALSE)
		tkadd(menuHelp, "command", label = "Add Package Highlighting", command = addHighlighting, underline = 0)
		tkadd(menuHelp, "command", label = "About rite Script Editor", command = about, underline = 0)
		tkadd(menuTop, "cascade", label = "Help", menu = menuHelp, underline = 0)

	pw <- tk2panedwindow(editor, orientation = orientation)
	nb1 <- tk2notebook(pw, tabs = c("Script")) # left pane
		# script editor
		edit_tab1 <- tk2notetab(nb1, "Script")
		edit_scr <- tkscrollbar(edit_tab1, repeatinterval=25, command=function(...){ tkyview(txt_edit,...) })
		txt_edit <- tk2ctext(edit_tab1, bg="white", undo="true",
								yscrollcommand=function(...) tkset(edit_scr,...),
								font=tkfont.create(family=fontFamily, size=fontSize))
		editModified <- function(){
			scriptSaved <<- FALSE
			tkwm.title(editor, paste("*",wmtitle))
		}
		tkbind(txt_edit, "<<Modified>>", editModified)
		tkgrid(txt_edit, sticky="nsew", column=1, row=1)
		tkgrid(edit_scr, sticky="nsew", column=2, row=1)
		tkgrid.columnconfigure(edit_tab1,1,weight=1)
		tkgrid.columnconfigure(edit_tab1,2,weight=0)
		tkgrid.rowconfigure(edit_tab1,1,weight=1)
			
		## SYNTAX HIGHLIGHTING RULES
		# latex
		if("latex" %in% highlight){
			# a macro without any brackets
			.Tcl(paste0("ctext::addHighlightClassForRegexp ",.Tk.ID(txt_edit)," latex1 darkred {\\\\[[:alnum:]|[:punct:]]+}"))
			# a macro with following brackets (and optionally [] brackets)
			.Tcl(paste0("ctext::addHighlightClassForRegexp ",.Tk.ID(txt_edit),
				" latex3 darkred {\\\\[[:alnum:]|[:punct:]]+\\[[[:alnum:]*|[:punct:]*|[:space:]*|=*]*\\]\\{[[:alnum:]|[:punct:]|[:space:]]*\\}}")) # a macro with following brackets
			# a macro with preceding brackets
			.Tcl(paste0("ctext::addHighlightClassForRegexp ",.Tk.ID(txt_edit)," latex4 darkred {\\{\\\\[[:alnum:]|[:punct:]]*[[:space:]]*[[:alnum:]|[:punct:]|[:space:]]*\\}}"))
			# comments
			.Tcl(paste0("ctext::addHighlightClassForRegexp ",.Tk.ID(txt_edit)," latexcomments red {%[^\n\r]*}"))
		}
		# r
		if("r" %in% highlight){
			# functions
			HLfuns <- lapply(search(),FUN=function(x) { paste0(unique(gsub("<-","",objects(x))),collapse=" ") })
			for(i in 1:length(HLfuns)){
				if(search()[i]=="package:base")
					HLfuns[[i]] <- substring(HLfuns[[i]],regexpr("abbreviate",HLfuns[[i]]),nchar(HLfuns[[i]]))
				.Tcl(paste0("ctext::addHighlightClass ",.Tk.ID(txt_edit)," functions",i," ",color,"  [list ",HLfuns[[i]]," ]"))
			}
			HLfuns <- NULL
			# operators
			.Tcl(paste0("ctext::addHighlightClass ",.Tk.ID(txt_edit)," specials blue  [list TRUE FALSE NULL NA if else ]"))
			.Tcl(paste0("ctext::addHighlightClassForSpecialChars ",.Tk.ID(txt_edit)," operators blue {@-+!~?:;*/^<>=&|$%,.}"))
			# comments
			.Tcl(paste0("ctext::addHighlightClassForRegexp ",.Tk.ID(txt_edit)," comments darkgreen {#[^\n\r]*}"))
			# brackets
			.Tcl(paste0("ctext::addHighlightClassForSpecialChars ",.Tk.ID(txt_edit)," brackets darkblue {[]{}()}"))
			# numbers
			.Tcl(paste0("ctext::addHighlightClassForRegexp ",.Tk.ID(txt_edit)," digits orange {[0-9]}"))
			# character
			.Tcl(paste0('ctext::addHighlightClassForRegexp ',.Tk.ID(txt_edit),' character1 darkgray {"(?:[^\\"]|\\.)*"}'))
			.Tcl(paste0("ctext::addHighlightClassForRegexp ",.Tk.ID(txt_edit)," character2 darkgray {'(?:[^\\']|\\.)*'}"))
		}
		
		## BRACKET COMPLETION
		closeP <- function(p){
			if(p=="(")
				q <- ")"
			else if(p=="[")
				q <- "]"
			else if(p=="{")
				q <- "}"
			else if(p=="'")
				q <- "'"
			else if(p=='"')
				q <- '"'
			else
				return()
			tkinsert(txt_edit, "insert", paste0(q))
			tkmark.set(txt_edit,"insert","insert-1char")
		}
		tkbind(txt_edit, "<Key-(>", function(...)closeP("("))
		tkbind(txt_edit, "<Key-[>", function(...)closeP("["))
		tkbind(txt_edit, "<Key-{>", function(...)closeP("{"))
		tkbind(txt_edit, "<Key-'>", function(...)closeP("'"))
		tkbind(txt_edit, '<Key-">', function(...)closeP('"'))
	# pack left notebook
	tkadd(pw, nb1, weight=1) # left pane

	if(catchOutput){
		nb2 <- tk2notebook(pw, tabs = c("Output", "Message"))#, "Plot")) # right pane
			# output
			out_tab1 <- tk2notetab(nb2, "Output")
			out_scr <- tkscrollbar(out_tab1, repeatinterval=25, command=function(...)tkyview(output,...))
			output <- tktext(out_tab1, height=25, bg="white", font="courier", yscrollcommand=function(...)tkset(out_scr,...),
										font=tkfont.create(family=fontFamily,size=fontSize))
			outModified <- function()
				outputSaved <<- FALSE
			tkbind(output, "<<Modified>>", outModified)
			tkconfigure(output, state="disabled")
			tkgrid(output, column=1, row=1, sticky="nsew")
			tkgrid(out_scr, column=2, row=1, sticky="nsew")
			tkgrid.columnconfigure(out_tab1,1,weight=1)
			tkgrid.columnconfigure(out_tab1,2,weight=0)
			tkgrid.rowconfigure(out_tab1,1,weight=1)
			
			# message
			out_tab2 <- tk2notetab(nb2, "Message")
			err_scr <- tkscrollbar(out_tab2, repeatinterval=25, command=function(...)tkyview(err_out,...))
			err_out <- tktext(out_tab2, height=25, bg="gray90", font="courier", yscrollcommand=function(...)tkset(err_scr,...),
										font=tkfont.create(family=fontFamily,size=fontSize))
			errModified <- function() {}
			tkbind(err_out, "<<Modified>>", errModified)
			tkconfigure(err_out, state="disabled")
			tkgrid(err_out, column=1, row=1, sticky="nsew")
			tkgrid(err_scr, column=2, row=1, sticky="nsew")
			tkgrid.columnconfigure(out_tab2,1,weight=1)
			tkgrid.columnconfigure(out_tab2,2,weight=0)
			tkgrid.rowconfigure(out_tab2,1,weight=1)
			
			# plot
			#out_tab3 <- tk2notetab(nb3, "Plot")
			#output <- tkrplot(out_tab3, width=50)
		# pack right notebook
		tkadd(pw, nb2, weight=1) # right pane
	}
	tkpack(pw, fill="both", expand = "yes") # pack panedwindow to editor

	### KEY BINDINGS ###	
	f1 <- function(){
		command <- tclvalue(tkget(txt_edit, "insert wordstart", "insert wordend"))
		if(command %in% c("","\n","("))
			command <- tclvalue(tkget(txt_edit, "insert-1char wordstart", "insert-1char wordend"))
		if(command %in% c("\n","\t"," ","(",")","[","]","{","}","=",",","*","/","+","-","^","%","$"))
			return()
		helpresults <- eval(parse(text=paste0("help(\"",command,"\")")))
		if(length(helpresults)==1)
			runCode(paste0("help(\"",command,"\")"))
		else
			runCode(paste0("help.search(\"",command,"\")"))
	}
	tkbind(txt_edit, "<F1>", f1)
	
	commandCompletion <- function(){
		iwordstart <- tclvalue(tkindex(txt_edit,"insert-1char wordstart"))
		iwordend <- tclvalue(tkindex(txt_edit,"insert-1char wordend"))
		command <- tclvalue(tkget(txt_edit, iwordstart, iwordend))
		if(command %in% c("","\n","("))
			command <- tclvalue(tkget(txt_edit, "insert-1char wordstart", "insert-1char wordend"))
		if(command %in% c("\n","\t"," ","(",")","[","]","{","}","=",",","*","/","+","-","^","%","$"))
			return()
		else{
			insertpos <- strsplit(tclvalue(tkindex(txt_edit,"insert")),".", fixed=TRUE)[[1]]
			fnlist <- apropos(paste0("^", command))
			if(length(fnlist<15))
				fnlist <- unique(c(fnlist, apropos(command)))
			if(length(fnlist)>0){
				insertCommand <- function(x){
					tkdelete(txt_edit, iwordstart, iwordend)
					tkinsert(txt_edit, "insert", fnlist[x])
				}
				fnContextMenu <- tkmenu(txt_edit, tearoff = FALSE)
				# conditionally add menu items
				## adding them programmatically failed to work (always added last command)
					if(length(fnlist)>0)
						tkadd(fnContextMenu, "command", label = fnlist[1], command = function() insertCommand(1))
					if(length(fnlist)>1)
						tkadd(fnContextMenu, "command", label = fnlist[1], command = function() insertCommand(1))
					if(length(fnlist)>2)
						tkadd(fnContextMenu, "command", label = fnlist[2], command = function() insertCommand(2))
					if(length(fnlist)>3)
						tkadd(fnContextMenu, "command", label = fnlist[3], command = function() insertCommand(3))
					if(length(fnlist)>4)
						tkadd(fnContextMenu, "command", label = fnlist[4], command = function() insertCommand(4))
					if(length(fnlist)>5)
						tkadd(fnContextMenu, "command", label = fnlist[5], command = function() insertCommand(5))
					if(length(fnlist)>6)
						tkadd(fnContextMenu, "command", label = fnlist[6], command = function() insertCommand(6))
					if(length(fnlist)>7)
						tkadd(fnContextMenu, "command", label = fnlist[7], command = function() insertCommand(7))
					if(length(fnlist)>8)
						tkadd(fnContextMenu, "command", label = fnlist[8], command = function() insertCommand(8))
					if(length(fnlist)>9)
						tkadd(fnContextMenu, "command", label = fnlist[9], command = function() insertCommand(9))
					if(length(fnlist)>10)
						tkadd(fnContextMenu, "command", label = fnlist[10], command = function() insertCommand(10))
					if(length(fnlist)>11)
						tkadd(fnContextMenu, "command", label = fnlist[11], command = function() insertCommand(11))
					if(length(fnlist)>12)
						tkadd(fnContextMenu, "command", label = fnlist[12], command = function() insertCommand(12))
					if(length(fnlist)>13)
						tkadd(fnContextMenu, "command", label = fnlist[13], command = function() insertCommand(13))
					if(length(fnlist)>14)
						tkadd(fnContextMenu, "command", label = fnlist[14], command = function() insertCommand(14))
				# root x,y
				rootx <- as.integer(tkwinfo("rootx", txt_edit))
				rooty <- as.integer(tkwinfo("rooty", txt_edit))
				# line height
				font <- strsplit(tclvalue(tkfont.metrics(fontFamily))," -")[[1]]
				lheight <- as.numeric(strsplit(font[grepl("linespace",font)]," ")[[1]][2])
				nl <- floor(as.numeric(iwordstart))
				# font width
				wordnchar <- as.numeric(strsplit(as.character(as.numeric(iwordend) %% 1),".",fixed=TRUE)[[1]][2])
				fontwidth <- as.numeric(tkfont.measure("m", fontFamily))
				# @x,y position
				xTxt <- rootx + wordnchar
				yTxt <- rooty + lheight*nl
				tkpost(fnContextMenu, xTxt, yTxt)
				tkbind(fnContextMenu, "<Shift-Tab>", function() tkunpost(fnContextMenu))
			}
		}
	}
	tkbind(txt_edit, "<Shift-Tab>", commandCompletion)
	tkbind(txt_edit, "<F2>", commandCompletion)
	
	casevar <- tclVar(1)
	regoptvar <- tclVar(0)
	updownvar <- tclVar(1)
	findreplace <- function(){
		startpos <- tclvalue(tkindex(txt_edit,"insert"))
		faillabeltext <- tclVar("")
		findtext <- function(string,startpos){
			searchterm <<- string
			if(string=="")
				return()
			else{
				found <- ""
				if(tclvalue(updownvar)==1){
					ud1 <- "-forwards"
					si1 <- "end"
				}
				else{
					ud1 <- "-backwards"
					si1 <- "0.0"
				}
				if(tclvalue(regoptvar)==0)
					reg1 <- "-exact"
				else
					reg1 <- "-regexp"
				if(tclvalue(casevar)==1)
					case1 <- "-nocase"
				else
					case1 <- ""
				found <- tclvalue(.Tcl(paste(.Tk.ID(txt_edit),"search",ud1,reg1,case1,string,startpos,si1)))
				if(!found==""){
					tkdestroy(searchDialog)
					tktag.add(txt_edit, "sel", found, paste0(found," +",nchar(string),"char"))
					if(tclvalue(updownvar)==1)
						tkmark.set(txt_edit, "insert", paste0(found," +",nchar(string),"char"))
					else
						tkmark.set(txt_edit, "insert", found)
				}
				else
					tclvalue(faillabeltext) <- "Text not found"
			}
		}
		replacetxt <- function(){
			# delete selection, if present
			# insert find text
			# find-next
		}
		if(searchterm=="")
			findval <- tclVar("")
		else
			findval <- tclVar(searchterm)
		searchDialog <- tktoplevel()
		tcl("wm", "attributes", searchDialog, topmost=TRUE)
		search1 <- function()
			tcl("wm", "attributes", searchDialog, alpha="1.0")
		searchTrans <- function()
			tcl("wm", "attributes", searchDialog, alpha="0.4")
		tkbind(searchDialog, "<FocusIn>", search1)
		tkbind(searchDialog, "<FocusOut>", searchTrans)
		tkwm.title(searchDialog, paste("Search", sep=""))	# title
		tkwm.iconbitmap(searchDialog, system.file("logo", "favicon.ico", package = "rite")) # CHANGE FILE TO BITMAP
		entryform <- tkframe(searchDialog, relief="groove", borderwidth=2)
			find.entry <- tkentry(entryform, width = 40, textvariable=findval)
			#replace.entry <- tkentry(entryform, width = 40, textvariable=replaceval)
			# grid
			tkgrid(tklabel(entryform, text = "   "), row=1, column=1, sticky="nsew")
			tkgrid(tklabel(entryform, text = "Find:   "), row=2, column=1, sticky="nsew")
			tkgrid(find.entry, row=2, column=2)
			tkgrid.configure(find.entry, sticky="nsew")
			#tkgrid(tklabel(entryform, text = "Replace:"), row=3, column=1, sticky="nsew")
			#tkgrid(replace.entry, row=3, column=2)
			#tkgrid.configure(replace.entry, sticky="nsew")
			tkgrid(tklabel(entryform, text = "   "), row=4, column=3)
			regform <- tkframe(entryform)
				regexopt <- tkcheckbutton(regform, variable=regoptvar)
				tkgrid(relabel <- tklabel(regform, text = "Use RegExp:   "), row=1, column=1, sticky="nsew")
				tkgrid(regexopt, row=1, column=2, sticky="nsew")
				tkbind(relabel, "<Button-3>", function() browseURL("http://www.tcl.tk/man/tcl8.4/TclCmd/re_syntax.htm"))
			tkgrid(regform, row=5, column=2, sticky="nsew")
			caseform <- tkframe(entryform)
				caseopt <- tkcheckbutton(caseform, variable=casevar)
				tkgrid(tklabel(caseform, text = "Ignore case? "), row=1, column=1, sticky="nsew")
				tkgrid(caseopt, row=1, column=2, sticky="nsew")	
			tkgrid(caseform, row=6, column=2, sticky="nsew")
			searchoptions <- tkframe(entryform)
				updown.up <- tkradiobutton(searchoptions, variable=updownvar, value=0)
				updown.down <- tkradiobutton(searchoptions, variable=updownvar, value=1)
				tkgrid(	tklabel(searchoptions, text = "Direction:   "),
						updown.up, 
						tklabel(searchoptions, text = "Up"), 
						updown.down,
						tklabel(searchoptions, text = "Down") )
			tkgrid(searchoptions, row=7, column=2, sticky="nsew")
			tkgrid.columnconfigure(entryform,1,weight=6)
			tkgrid.columnconfigure(entryform,2,weight=10)
			tkgrid.columnconfigure(entryform,3,weight=2)
		tkgrid(entryform, row=1, column=2)
		tkgrid.configure(entryform, sticky="nsew")
		buttons <- tkframe(searchDialog)
			# buttons
			Findbutton <- tkbutton(buttons, text = " Find Next ", width=12, command = function() findtext(tclvalue(findval),startpos))
			#Replacebutton <- tkbutton(buttons, text = "  Replace  ", width=12, command = function() replacetext(tclvalue(replaceval)))
			Cancelbutton <- tkbutton(buttons, text = "     Close     ", width=12, command = function(){ tkdestroy(searchDialog); tkfocus(txt_edit) } )
			tkgrid(tklabel(buttons, text = "        "), row=1, column=1)
			tkgrid(Findbutton, row=2, column=2)
			faillabel <- tklabel(buttons, text=tclvalue(faillabeltext), foreground="red")
			tkconfigure(faillabel,textvariable=faillabeltext)
			tkgrid(faillabel, row=3, column=1, columnspan=3)
			#tkgrid(Replacebutton, row=3, column=2)
			tkgrid(tklabel(buttons, text = "        "), row=4, column=2)
			tkgrid(Cancelbutton, row=5, column=2)
			tkgrid(tklabel(buttons, text = "        "), row=6, column=3)
			tkgrid.columnconfigure(buttons,1,weight=2)
			tkgrid.columnconfigure(buttons,2,weight=10)
			tkgrid.columnconfigure(buttons,3,weight=2)
		tkgrid(buttons, row=1, column=3)
		tkgrid.configure(buttons, sticky="nsew")
		tkgrid.columnconfigure(searchDialog,2,weight=1)
		tkgrid.columnconfigure(searchDialog,3,weight=1)
		tkgrid.rowconfigure(searchDialog,1,weight=2)
		tkwm.resizable(searchDialog,0,0)
		tkbind(find.entry, "<Return>", function() findtext(tclvalue(findval),startpos))
		tkbind(find.entry, "<KeyPress>", function() tclvalue(faillabeltext) <- "")
		tkfocus(find.entry)
	}
	tkbind(txt_edit, "<F3>", findreplace)
	tkbind(txt_edit, "<Control-F>", findreplace)
	tkbind(txt_edit, "<Control-f>", findreplace)
	
	gotoline <- function(){
		jump <- function(){
			lineval <- tclvalue(lineval)
			if(!lineval=="")
				tkmark.set(txt_edit,"insert",paste0(lineval,".0"))
			tkdestroy(goDialog)
			tksee(txt_edit,"insert")
		}
		goDialog <- tktoplevel()
		tkwm.title(goDialog, paste("Go to line",sep=""))	# title
		tkwm.iconbitmap(goDialog,system.file("logo", "favicon.ico", package = "rite")) # CHANGE FILE TO BITMAP
		entryform <- tkframe(goDialog, relief="groove", borderwidth=2)
			lineval <- tclVar("")
			line.entry <- tkentry(goDialog, width = 5, textvariable=lineval)
			gobutton <- tkbutton(entryform, text = " Go ", command = jump)
			tkgrid(tklabel(entryform, text = "    Line: "), line.entry, gobutton)
			tkbind(line.entry, "<Return>", jump)
		tkgrid(entryform)
		tkfocus(line.entry)
	}
	tkbind(txt_edit, "<Control-G>", gotoline)
	tkbind(txt_edit, "<Control-g>", gotoline)
	
	tryparse <- function(){
		sel <- tclvalue(tktag.ranges(txt_edit,"sel"))
		if(!sel=="")
			e <- try(parse(text=tclvalue(tkget(txt_edit,"sel.first","sel.last"))), silent=TRUE)
		else
			e <- try(parse(text=tclvalue(tkget(txt_edit,"1.0","end"))), silent=TRUE)
		if(inherits(e, "try-error")) {
			e <- strsplit(e,"<text>")[[1]][2]
			if(!sel=="")
				linen <- paste(	(as.numeric(strsplit(e,":")[[1]][2]) + as.numeric(strsplit(sel,"[.]")[[1]][1]) - 1), 
								(as.numeric(strsplit(e,":")[[1]][3])-1), sep=".")
			else
				linen <- paste(	strsplit(e,":")[[1]][2], strsplit(e,":")[[1]][3], sep=".")
			content <- strsplit(e,":")[[1]]
			tktag.add(txt_edit,"sel",paste(linen,"linestart"),paste(linen,"lineend"))
			tkmark.set(txt_edit,"insert",paste0(linen,"-1char"))
			cat("\a")
			invisible(FALSE)
		}
		else{
			tkmessageBox(message="No syntax errors found")
			tkfocus(txt_edit)
			invisible(TRUE)
		}
	}
	tkbind(txt_edit, "<F7>", tryparse)
	
	runkey <- function() {
		if(!tclvalue(tktag.ranges(txt_edit,"sel"))=="")
			runCode(tclvalue(tkget(txt_edit,"sel.first","sel.last")))
		else
			runLine()
	}
	tkbind(txt_edit, "<Control-r>", runkey)
	tkbind(txt_edit, "<Control-R>", runkey)
	tkbind(txt_edit, "<F8>", runAll)
	
	tkbind(txt_edit, "<Control-s>", saveScript)
	tkbind(txt_edit, "<Control-S>", saveScript)
	
	tkbind(txt_edit, "<Control-o>", expression(loadScript(filename=NULL), break))
	tkbind(txt_edit, "<Control-O>", expression(loadScript(filename=NULL), break))
	
	if(catchOutput){
		tkbind(txt_edit, "<Control-l>", clearOutput)
		tkbind(output, "<Control-l>", clearOutput)
		tkbind(txt_edit, "<Control-L>", clearOutput)
		tkbind(output, "<Control-L>", clearOutput)
	}
	
	toggleComment <- function(){
		checkandtoggle <- function(pos){
			check <- tclvalue(tkget(txt_edit, pos, paste0(pos,"+2char")))
			if(check=="# ")
				tkdelete(txt_edit, pos, paste0(pos,"+2char"))
			else if(substring(check,1,1)=="#")
				tkdelete(txt_edit, pos, paste0(pos,"+1char"))
			else{
				tkmark.set(txt_edit,"insert",pos)
				tkinsert(txt_edit, "insert", "# ")
			}
		}
		selrange <- tclvalue(tktag.ranges(txt_edit,"sel"))
		if(!selrange==""){
			selrange <- round(as.numeric(strsplit(selrange," ")[[1]]),0)
			for(i in selrange[1]:(selrange[2]-1))
				checkandtoggle(paste0(i,".0 linestart"))
		}
		else
			checkandtoggle("insert linestart")
	}
	tkbind(txt_edit, "<Control-k>", expression(toggleComment, break))
	tkbind(txt_edit, "<Control-k>", expression(toggleComment, break))
	
	multitab <- function(){
		insertpos <- strsplit(tclvalue(tkindex(txt_edit,"insert")),".", fixed=TRUE)[[1]]
		insertpos2 <- paste0(insertpos[1],".",as.numeric(insertpos[2])+1)
		selrange <- tclvalue(tktag.ranges(txt_edit,"sel"))
		if(selrange=="")
			tkinsert(txt_edit, paste0(insertpos[1],".0"), "\t")
		else{
			selrange <- floor(as.numeric(strsplit(selrange," ")[[1]]))
			if(selrange[1]==selrange[2])
				tkinsert(txt_edit, paste(selrange[1],".0 linestart"), "\t")
			else{
				for(i in selrange[1]:selrange[2])
					tkinsert(txt_edit, paste0(i,".0 linestart"), "\t")
			}
		}
		tkmark.set(txt_edit, "insert", insertpos2)
	}
	multiuntab <- function(){
		insertpos <- strsplit(tclvalue(tkindex(txt_edit,"insert")),".", fixed=TRUE)[[1]]
		insertpos2 <- paste0(insertpos[1],".",as.numeric(insertpos[2])-1)
		selrange <- tclvalue(tktag.ranges(txt_edit,"sel"))
		if(!selrange==""){
			selrange <- round(as.numeric(strsplit(selrange," ")[[1]]),0)
			for(i in selrange[1]:selrange[2]){
				pos <- paste0(i,".0 linestart")
				check <- tclvalue(tkget(txt_edit, pos, paste0(pos,"+1char")))
				if(check=="\t")
					tkdelete(txt_edit, pos, paste0(pos,"+1char"))
			}
			tkmark.set(txt_edit, "insert", insertpos2)
		}
		else{
			check <- tclvalue(tkget(txt_edit, "insert linestart", "insert linestart+1char"))
			if(check=="\t"){
				tkmark.set(txt_edit, "insert", "insert linestart")
				tkdelete(txt_edit, "insert linestart", "insert linestart+1char")
				tkmark.set(txt_edit, "insert", insertpos2)
			}
		}
	}
	tkbind(txt_edit, "<Control-i>", expression(multitab, break))
	tkbind(txt_edit, "<Control-I>", expression(multitab, break))
	tkbind(txt_edit, "<Control-u>", multiuntab)
	tkbind(txt_edit, "<Control-U>", multiuntab)
	
	tabreturn <- function(){
		# detect tab(s)
		tab1 <- tclvalue(tkget(txt_edit, "insert linestart", "insert linestart+1char"))
		tabs <- 0
		if(tab1=="\t"){
			tabs <- tabs + 1
			more <- TRUE
			while(more){
				tab2 <- tclvalue(tkget(txt_edit, paste0("insert linestart+",tabs,"char"), paste0("insert linestart+",tabs+1,"char")))
				if(tab2=="\t")
					tabs <- tabs + 1
				else
					more <- FALSE
			}
		}
		tkinsert(txt_edit, "insert ", paste0("\n",paste(rep("\t",tabs),collapse="")))
		tksee(txt_edit, "insert")
	}
	tkbind(txt_edit, "<Return>", expression(tabreturn, break))
	
	### CONTEXT MENU ###
	selectAllEdit <- function(){
		tktag.add(txt_edit,"sel","0.0","end")
		tkmark.set(txt_edit,"insert","end")
	}
	tkbind(txt_edit, "<Control-A>", expression(selectAllEdit, break))
	tkbind(txt_edit, "<Control-a>", expression(selectAllEdit, break))
	
	copyText <- function(cut=FALSE){
		selrange <- strsplit(tclvalue(tktag.ranges(txt_edit,"sel"))," ")[[1]]
		if(!selrange==""){
			tkclipboard.clear()
			tkclipboard.append(tclvalue(tkget(txt_edit, selrange[1], selrange[2])))
			if(cut)
				tkdelete(txt_edit, selrange[1], selrange[2])
		}
		else
			cat("\a")
	}
	pasteText <- function(){
		if("windows"==.Platform$OS.type)
			cbcontents <- readLines("clipboard")
		else if("unix"==Sys.getenv("OS"))
			cbcontents <- readLines(pipe("pbpaste"))
		else
			cbcontents <- ""
		tkinsert(txt_edit, "insert", paste(cbcontents,collapse="\n"))
	}
	contextMenu <- tkmenu(txt_edit, tearoff = FALSE)
		tkadd(contextMenu, "command", label = "Run line/selection <Ctrl-R>", command = runkey)
		tkadd(contextMenu, "command", label = "Parse all <F7>", command = tryparse)
		tkadd(contextMenu, "command", label = "Run all <F8>", command = runAll)
		tkadd(contextMenu, "separator")
		tkadd(contextMenu, "command", label = "Select All <Ctrl-A>", command = selectAllEdit)
		tkadd(contextMenu, "command", label = "Copy <Ctrl-C>", command = copyText)
		tkadd(contextMenu, "command", label = "Cut <Ctrl-X>", command = function() copyText(cut=TRUE))
		tkadd(contextMenu, "command", label = "Paste <Ctrl-V>", command = pasteText)
		tkadd(contextMenu, "separator")
		tkadd(contextMenu, "command", label = "Find <Ctrl-F>", command = findreplace)
		tkadd(contextMenu, "command", label = "Go to line <Ctrl-G>", command = gotoline)
		tkadd(contextMenu, "separator")
		tkadd(contextMenu, "command", label = "Lookup Function <F1>", command = f1)
	rightClick <- function(x, y) {
		rootx <- as.integer(tkwinfo("rootx", txt_edit))
		rooty <- as.integer(tkwinfo("rooty", txt_edit))
		xTxt <- as.integer(x) + rootx
		yTxt <- as.integer(y) + rooty
		tkmark.set(txt_edit,"insert",paste0("@",xTxt,",",yTxt))
		.Tcl(paste("tk_popup", .Tcl.args(contextMenu, xTxt, yTxt)))
	}
	tkbind(txt_edit, "<Button-3>", rightClick)
	
	# DISPLAY EDITOR
	if(!is.null(filename))
		loadScript(filename=filename)
	tkmark.set(txt_edit,"insert","1.0")
	if(catchOutput){
		tcl("wm", "state", editor, "zoomed")
		tcl("wm", "attributes", editor, "zoomed")
	}
	tkfocus(txt_edit)
	tksee(txt_edit, "insert")
}
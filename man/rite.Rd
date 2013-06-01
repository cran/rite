\name{rite}
\alias{rite}
\title{rite}
\description{Open rite}
\usage{
rite(filename=NULL, catchOutput=FALSE, evalenv=.GlobalEnv,
     fontFamily="Courier", fontSize=10, orientation="horizontal", 
	 highlight=c("r","latex"), color="purple", ...)
}
\arguments{
  \item{filename}{Optionally, a character string specifying a file name in the working directory (or file path) to open in rite.}
  \item{catchOutput}{A logical specifying whether output and event handling (errors, warnings, messages, interrupts) should be sent to the rite output viewer panel rather than the R console. Default is \code{FALSE}.}
  \item{evalenv}{The environment in which the script should be evaluated, e.g., \code{.GlobalEnv}. If \code{NULL}, the default is a hidden environment, internal to \code{rite} meaning that, e.g., variables created/modified in \code{rite} are not accessible via the console.}
  \item{fontFamily}{The font family used in rite. Default is \dQuote{\code{Courier}}. Available fonts can be retrieved by \code{.Tcl("font families")}.}
  \item{fontSize}{The font size used in rite. Default is \code{10}.}
  \item{orientation}{If \code{catchOutput=TRUE}, whether the output and error panels should be oriented \dQuote{horizontal} (to the right) or \dQuote{vertical} (below) the script editing panel. Default is \dQuote{horizontal}.}
  \item{highlight}{A character vector containing one or more of \dQuote{r}, \dQuote{latex}, to indicate what should be higlighted in script.}
  \item{color}{A character vector specifying the color to use for syntax highlighting (for functions). Default is \dQuote{purple}.}
  \item{...}{Ignored}
}
\details{
Create, edit, and save R scripts (or any text-based file) and, optionally, sink output to an output viewer rather than the R console.

Scripts can be loaded, appended, referenced (via \code{source}) in the current script, and can be saved.

Scripts can be run by selection, line, or the entire contents of the script editor from the \dQuote{Run} menu. Scripts can also be run from the context menu (via a right mouse click) or with \code{<Control-r>}. \code{<F8>} runs the entire script, whereas \code{<F7>} checks for parsing errors in the entire script without evaluating it.
}

\section{Shortcut keys in widget}{
	\subsection{Key combinations}{
	
	\code{<Ctrl-o>}: Open script
	
	\code{<Ctrl-s>}: Save script as
	
	\code{<Ctrl-r>}: Run/evaluate line/selection
	
	\code{<Ctrl-c>}: Copy
	
	\code{<Ctrl-x>}: Cut
	
	\code{<Ctrl-p>}: Paste
	
	\code{<Ctrl-a>}: Select all
	
	\code{<Ctrl-e>}: Move cursor to end of current line
	
	\code{<Shift-e>}: Adjust selection to end of current line
	
	\code{<Ctrl-f>}: Find/replace
	
	\code{<Ctrl-g>}: Go to line
	
	\code{<Ctrl-z>}: Undo
	
	\code{<Ctrl-y>}: Redo
	
	\code{<Tab>}: Indent line
	
	\code{<Ctrl-i>}: Indent line(s)
	
	\code{<Ctrl-u>}: Unindent line
	
	\code{<Ctrl-k>}: Toggle comment on/off for line(s)
	
	\code{<Shift-Tab>}: Open command completion context menu (based on cursor position)
	
	\code{<Ctrl-l>}: Clear output panel
	
	\code{<Shift>} and \code{<Left>}, \code{<Right>}, or drag left mouse: Adjust selection by character
	
	\code{<Control-Shift-Left>} or \code{<Control-Shift-Right>}: Adjust selection by word
	
	\code{<Control-Up>} or \code{<Control-Down>}: Move insertion cursor by paragraphs
	
	\code{<Control-Shift-Up>} or \code{<Control-Shift-Down>}: Adjust selection by paragraph
	}

	\subsection{Function keys}{
	
	\code{<F1>}: Open help for current function, if a known function (based on cursor position); or the results of help.search()
	
	\code{<F2>}: Open command completion context menu (based on cursor position)
	
	\code{<F3>}: Find
	
	\code{<F7>}: Try to parse the script and return any syntax errors (does not evaluate the script)
	
	\code{<F8>}: Run/evaluate all code
	}

	\subsection{Mouse shortcuts}{
	
	Left mouse click (1 time): Move cursor
	
	Left mouse click (2 times): Select word
	
	Left mouse click (3 times): Select line
	
	Right mouse click (1 time): Open context menu
	}
}
%\value{}
%\references{}
\author{Thomas J. Leeper}
%\note{}
%\seealso{}
%\examples{\dontrun{rite(catchOutput=TRUE)}}
\keyword{ IO }
#!/usr/bin/python
# Copyright 2008 Marcus D. Hanwell <marcus@cryos.org>
# Copyright 2011 Sebastian Poelsterl <sebp@k-d-w.org>
# Distributed under the terms of the GNU General Public License v2 or later

import string
import re
import os
import sys
import textwrap

class ChangeLogGenerator:

    def __init__(self):
        self.reset()
        self.fout = None
        self.commitFound = False

    def reset(self):
        # Set up the loop variables in order to locate the blocks we want
        self.authorFound = False
        self.dateFound = False
        self.messageFound = False
        self.messageNL = False
        self.message = ["", ]
        self.filesFound = False
        self.filesModified = set()
        self.filesAdded = set()
        self.filesDeleted = set()
        self.prevAuthorLine = ""

        self.date = None
        self.author = None
        self.tag = None

    def run(self):
        # Execute git log with the desired command line options.
        fin = os.popen('git log --summary --numstat --no-merges --date=short --decorate', 'r')
        # Create a ChangeLog file in the current directory.
        self.fout = sys.stdout

        # The main part of the loop
        for line in fin:
            self.process_line(line)
        self.write_commit()
        # Close the input and output lines now that we are finished.
        fin.close()
        self.fout.close()

    def process_line(self, line):
        # The commit line marks the start of a new commit object.
        if line.startswith('commit'):
            if self.commitFound:
                self.write_commit()

            # Start all over again...
            self.reset()
            self.commitFound = True

            match = re.match(r'commit ([0-9a-f]+) \(tag: (.+)\)', line)
            if match != None:
                self.tag = match.group(2)
        # Match the author line and extract the part we want
        elif re.match('Author:', line) >=0:
            authorList = re.split(': ', line, 1)
            author = authorList[1]
            self.author = author[0:len(author)-1]
            self.authorFound = True
        # Match the date line
        elif re.match('Date:', line) >= 0:
            dateList = re.split(':   ', line, 1)
            date = dateList[1]
            self.date = date[0:len(date)-1]
            self.dateFound = True
        # The svn-id lines are ignored
        elif re.match('    git-svn-id:', line) >= 0:
            pass
        # The sign off line is ignored too
        elif re.search('Signed-off-by', line) >= 0:
            pass
        # Extract the actual commit message for this commit
        elif self.authorFound and self.dateFound and not self.messageFound:
            # Find the commit message if we can
            if len(line) == 1:
                if self.messageNL:
                    # After commit message
                   self.messageFound = True
                else:
                    # Before commit message
                    self.messageNL = True
            elif len(line) == 5:
                # blank line in commit message
                self.message.append("")
            else:
                msg = line.strip().replace("\n", "")
                if len(self.message[-1]) == 0:
                    self.message[-1] = msg
                else:
                    self.message[-1] += " " + msg
        # Collect the files for this commit.
        elif self.authorFound and self.dateFound and self.messageFound:
            fileList = line.split('\t', 3)
            if len(fileList) > 1:
                self.filesModified.add(fileList[2].strip())
            else:
                self.filesFound = True
        # All of the parts of the commit have been found - write out the entry
        if self.authorFound and self.dateFound and self.messageFound and self.filesFound:
            match = re.match(r' create mode ([0-9]+) (.+)', line)
            if match != None:
                f = match.group(2)
                self.filesAdded.add(f)
                self.filesModified.remove(f)
            else:
                match = re.match(r' delete mode ([0-9]+) (.+)', line)
                if match != None:
                    f = match.group(2)
                    self.filesDeleted.add(f)
                    self.filesModified.remove(f)

    def write_commit(self):
        if self.tag != None:
            self.fout.write("=== %s ===\n" % self.tag)

        # First the author line, only outputted if it is the first for that
        # author on this day
        authorLine = self.date + "  " + self.author
        if len(self.prevAuthorLine) == 0:
            self.fout.write(authorLine + "\n")
        elif authorLine == self.prevAuthorLine:
            pass
        else:
            self.fout.write("\n" + authorLine + "\n")

        # Assemble the actual commit message line(s) and limit the line length
        # to 80 characters.
        files = self.files_to_string(self.filesAdded)
        if files != None:
            self.fout.write(files + ": Added.\n")

        files = self.files_to_string(self.filesDeleted)
        if files != None:
            self.fout.write(files + ": Removed.\n")

        files = self.files_to_string(self.filesModified)
        if files != None:
            self.fout.write(files + ": Modified.\n")

        commit = "\n"
        for paragraph in self.message:
            commit += self.wrap_text(paragraph)
            commit += "\n\n"

        # Write out the commit line
        self.fout.write(commit)
        self.prevAuthorLine = authorLine

    def wrap_text(self, commitLine):
        txt = textwrap.wrap(commitLine, initial_indent='   ', subsequent_indent='   ')
        return "\n".join(txt)

    def files_to_string(self, somelist):
        files = ""
        for f in somelist:
            files += "\n  * " + f + ","
        if len(files) > 0:
            return files[:-1]

if __name__ == '__main__':
    c = ChangeLogGenerator()
    c.run()

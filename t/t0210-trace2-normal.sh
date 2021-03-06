#!/bin/sh

test_description='test trace2 facility (normal target)'
. ./test-lib.sh

# Turn off any inherited trace2 settings for this test.
sane_unset GIT_TR2 GIT_TR2_PERF GIT_TR2_EVENT
sane_unset GIT_TR2_BRIEF
sane_unset GIT_TR2_CONFIG_PARAMS

# Add t/helper directory to PATH so that we can use a relative
# path to run nested instances of test-tool.exe (see 004child).
# This helps with HEREDOC comparisons later.
TTDIR="$GIT_BUILD_DIR/t/helper/" && export TTDIR
PATH="$TTDIR:$PATH" && export PATH

# Warning: use of 'test_cmp' may run test-tool.exe and/or git.exe
# Warning: to do the actual diff/comparison, so the HEREDOCs here
# Warning: only cover our actual calls to test-tool and/or git.
# Warning: So you may see extra lines in artifact files when
# Warning: interactively debugging.

V=$(git version | sed -e 's/^git version //') && export V

# There are multiple trace2 targets: normal, perf, and event.
# Trace2 events will/can be written to each active target (subject
# to whatever filtering that target decides to do).
# This script tests the normal target in isolation.
#
# Defer setting GIT_TR2 until the actual command line we want to test
# because hidden git and test-tool commands run by the test harness
# can contaminate our output.

# Enable "brief" feature which turns off "<clock> <file>:<line> " prefix.
GIT_TR2_BRIEF=1 && export GIT_TR2_BRIEF

# Basic tests of the trace2 normal stream.  Since this stream is used
# primarily with printf-style debugging/tracing, we do limited testing
# here.
#
# We do confirm the following API features:
# [] the 'version <v>' event
# [] the 'start <argv>' event
# [] the 'cmd_name <name>' event
# [] the 'exit <time> code:<code>' event
# [] the 'atexit <time> code:<code>' event
#
# Fields of the form _FIELD_ are tokens that have been replaced (such
# as the elapsed time).

# Verb 001return
#
# Implicit return from cmd_<verb> function propagates <code>.

test_expect_success 'normal stream, return code 0' '
	test_when_finished "rm trace.normal actual expect" &&
	GIT_TR2="$(pwd)/trace.normal" test-tool trace2 001return 0 &&
	perl "$TEST_DIRECTORY/t0210/scrub_normal.perl" <trace.normal >actual &&
	cat >expect <<-EOF &&
		version $V
		start _EXE_ trace2 001return 0
		cmd_name trace2 (trace2)
		exit elapsed:_TIME_ code:0
		atexit elapsed:_TIME_ code:0
	EOF
	test_cmp expect actual
'

test_expect_success 'normal stream, return code 1' '
	test_when_finished "rm trace.normal actual expect" &&
	test_must_fail env GIT_TR2="$(pwd)/trace.normal" test-tool trace2 001return 1 &&
	perl "$TEST_DIRECTORY/t0210/scrub_normal.perl" <trace.normal >actual &&
	cat >expect <<-EOF &&
		version $V
		start _EXE_ trace2 001return 1
		cmd_name trace2 (trace2)
		exit elapsed:_TIME_ code:1
		atexit elapsed:_TIME_ code:1
	EOF
	test_cmp expect actual
'

test_expect_success 'automatic filename' '
	test_when_finished "rm -r traces actual expect" &&
	mkdir traces &&
	GIT_TR2="$(pwd)/traces" test-tool trace2 001return 0 &&
	perl "$TEST_DIRECTORY/t0210/scrub_normal.perl" <"$(ls traces/*)" >actual &&
	cat >expect <<-EOF &&
		version $V
		start _EXE_ trace2 001return 0
		cmd_name trace2 (trace2)
		exit elapsed:_TIME_ code:0
		atexit elapsed:_TIME_ code:0
	EOF
	test_cmp expect actual
'

# Verb 002exit
#
# Explicit exit(code) from within cmd_<verb> propagates <code>.

test_expect_success 'normal stream, exit code 0' '
	test_when_finished "rm trace.normal actual expect" &&
	GIT_TR2="$(pwd)/trace.normal" test-tool trace2 002exit 0 &&
	perl "$TEST_DIRECTORY/t0210/scrub_normal.perl" <trace.normal >actual &&
	cat >expect <<-EOF &&
		version $V
		start _EXE_ trace2 002exit 0
		cmd_name trace2 (trace2)
		exit elapsed:_TIME_ code:0
		atexit elapsed:_TIME_ code:0
	EOF
	test_cmp expect actual
'

test_expect_success 'normal stream, exit code 1' '
	test_when_finished "rm trace.normal actual expect" &&
	test_must_fail env GIT_TR2="$(pwd)/trace.normal" test-tool trace2 002exit 1 &&
	perl "$TEST_DIRECTORY/t0210/scrub_normal.perl" <trace.normal >actual &&
	cat >expect <<-EOF &&
		version $V
		start _EXE_ trace2 002exit 1
		cmd_name trace2 (trace2)
		exit elapsed:_TIME_ code:1
		atexit elapsed:_TIME_ code:1
	EOF
	test_cmp expect actual
'

# Verb 003error
#
# To the above, add multiple 'error <msg>' events

test_expect_success 'normal stream, error event' '
	test_when_finished "rm trace.normal actual expect" &&
	GIT_TR2="$(pwd)/trace.normal" test-tool trace2 003error "hello world" "this is a test" &&
	perl "$TEST_DIRECTORY/t0210/scrub_normal.perl" <trace.normal >actual &&
	cat >expect <<-EOF &&
		version $V
		start _EXE_ trace2 003error '\''hello world'\'' '\''this is a test'\''
		cmd_name trace2 (trace2)
		error hello world
		error this is a test
		exit elapsed:_TIME_ code:0
		atexit elapsed:_TIME_ code:0
	EOF
	test_cmp expect actual
'

sane_unset GIT_TR2_BRIEF

# Now test without environment variables and get all Trace2 settings
# from the global config.

test_expect_success 'using global config, normal stream, return code 0' '
	test_when_finished "rm trace.normal actual expect" &&
	test_config_global trace2.normalBrief 1 &&
	test_config_global trace2.normalTarget "$(pwd)/trace.normal" &&
	test-tool trace2 001return 0 &&
	perl "$TEST_DIRECTORY/t0210/scrub_normal.perl" <trace.normal >actual &&
	cat >expect <<-EOF &&
		version $V
		start _EXE_ trace2 001return 0
		cmd_name trace2 (trace2)
		exit elapsed:_TIME_ code:0
		atexit elapsed:_TIME_ code:0
	EOF
	test_cmp expect actual
'

test_expect_success 'using global config with include' '
	test_when_finished "rm trace.normal actual expect real.gitconfig" &&
	test_config_global trace2.normalBrief 1 &&
	test_config_global trace2.normalTarget "$(pwd)/trace.normal" &&
	mv "$(pwd)/.gitconfig" "$(pwd)/real.gitconfig" &&
	test_config_global include.path "$(pwd)/real.gitconfig" &&
	test-tool trace2 001return 0 &&
	perl "$TEST_DIRECTORY/t0210/scrub_normal.perl" <trace.normal >actual &&
	cat >expect <<-EOF &&
		version $V
		start _EXE_ trace2 001return 0
		cmd_name trace2 (trace2)
		exit elapsed:_TIME_ code:0
		atexit elapsed:_TIME_ code:0
	EOF
	test_cmp expect actual
'

test_done

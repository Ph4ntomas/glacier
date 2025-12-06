TEST_TIMEOUT = 10

function assert_loop(cq, timeout)
    local ok, err, _, thd = cq:loop(timeout)
    if not ok then
        if thd then
            err = debug.traceback(thd, err)
        end
        error(err, 2)
    end
end

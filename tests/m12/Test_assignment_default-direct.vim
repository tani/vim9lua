def Test_assignment_default()
  # Test default values.
  var thebool: bool
  assert_equal(v:false, thebool)

  var thenumber: number
  assert_equal(0, thenumber)

  var thefloat: float
  assert_equal(0.0, thefloat)

  var thestring: string
  assert_equal('', thestring)

  var theblob: blob
  assert_equal(0z, theblob)

  var Thefunc: func
  assert_equal(test_null_function(), Thefunc)

  var thelist: list<any>
  assert_equal([], thelist)

  var thedict: dict<any>
  assert_equal({}, thedict)

  if has('channel')
    var thejob: job
    assert_equal(test_null_job(), thejob)

    var thechannel: channel
    assert_equal(test_null_channel(), thechannel)

    if has('unix') && executable('cat')
      # check with non-null job and channel, types must match
      thejob = job_start("cat ", {})
      thechannel = job_getchannel(thejob)
      job_stop(thejob, 'kill')
    endif
  endif

  var nr = 1234 | nr = 5678
  assert_equal(5678, nr)
enddef
call Test_assignment_default()

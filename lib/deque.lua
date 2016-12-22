local module = {}

function module.Deque()
  local q = {first = 0, last = -1}
  
  function q.PeekFirst()
    return q[q.first]
  end
  
  function q.PeekLast()
    return q[q.last]
  end
  
  function q.PollFirst()
    local res = q[q.first]
    if q.first <= q.last then
      q[q.first] = nil
      q.first = q.first + 1
    end
    return res
  end
  
  function q.PollLast()
    local res = q[q.last]
    if q.first <= q.last then
      q[q.last] = nil
      q.last = q.last - 1
    end
    return res
  end
  
  function q.AddFirst(value)
    q.first = q.first - 1
    q[q.first] = value
  end
  
  function q.AddLast(value)
    q.last = q.last + 1
    q[q.last] = value
  end
  
  function q.Empty()
    return q.first > q.last
  end
  
  return q
end

return module
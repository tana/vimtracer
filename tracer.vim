" Ray tracer in Vim Script

" minimum value in a float list
function! s:fmin(lst)
  let min_value = a:lst[0]
  for value in a:lst
    if value < min_value
      let min_value = value
    endif
  endfor
  return min_value
endfunction

" vector operations
function! s:vadd(a, b)
  return [a:a[0] + a:b[0], a:a[1] + a:b[1], a:a[2] + a:b[2]]
endfunction

function! s:vsub(a, b)
  return [a:a[0] - a:b[0], a:a[1] - a:b[1], a:a[2] - a:b[2]]
endfunction

function! s:scale(s, v)
  return [a:s * a:v[0], a:s * a:v[1], a:s * a:v[2]]
endfunction

function! s:dot(a, b)
  return a:a[0] * a:b[0] + a:a[1] * a:b[1] + a:a[2] * a:b[2]
endfunction

function! s:vlen_sq(v)
  return s:dot(a:v, a:v)
endfunction

function! s:vlen(v)
  return sqrt(s:vlen_sq(a:v))
endfunction

function! s:normalize(v)
  return s:scale(1/s:vlen(a:v), a:v)
endfunction

let s:width = 256
let s:height = 256

function! s:solve_quad(a, b, c)
  let d = a:b * a:b - 4 * a:a * a:c
  if d > 0.0
    return [(-a:b + sqrt(d)) / (2 * a:a), (-a:b - sqrt(d)) / (2 * a:a)]
  elseif d == 0.0
    return [(-a:b) / (2 * a:a)]
  else
    return []
  endif
endfunction

function! s:intersect(ray, sph)
  let a = s:vlen_sq(a:ray[0])
  let b = 2.0 * s:dot(a:ray[0], s:vsub(a:ray[1], a:sph[0]))
  let c = s:vlen_sq(s:vsub(a:ray[1], a:sph[0])) - a:sph[1] * a:sph[1]
  let solutions = s:solve_quad(a, b, c)
  call filter(solutions, "v:val > 0")
  if empty(solutions)
    return []
  else
    return [s:fmin(solutions)]
  endif
endfunction

function! s:nearest_intersection(lst)
  let min_value = a:lst[0]
  for value in a:lst
    if value[0] < min_value[0]
      let min_value = value
    endif
  endfor
  return min_value
endfunction

function! s:reflect_ray(ray, point, normal)
  let vec = s:vadd(a:ray[0], s:scale(-2.0 * s:dot(a:normal, a:ray[0]), a:normal))
  let vec = s:normalize(vec)
  return [vec, s:vadd(a:point, s:scale(0.01, a:normal)), a:ray[2] + 1]
endfunction


" [center, radius, color, specular]
let s:spheres = [
  \ [[-0.6, 0.0, -3.0], 0.5, [1.0, 0.0, 0.0], 0.5],
  \ [[0.6, 0.0, -3.0], 0.5, [0.0, 1.0, 0.0], 0.5],
  \ [[0.0, -1001.0, 0], 1000.0, [1.0, 1.0, 1.0], 0.0]]

" light position
let s:light = [0.0, 5.0, 5.0]

function! s:all_intersections(ray)
  let intersections = []
  for sph in s:spheres
    let sph_intersect = s:intersect(a:ray, sph)
    if !empty(sph_intersect)
      call add(intersections, [sph_intersect[0], sph])
    endif
  endfor
  return intersections
endfunction

" ray = [vector, start, recursion_depth]
function! s:trace(ray)
  if a:ray[2] > 5
    return [0.0, 0.0, 0.0]
  endif

  let intersections = s:all_intersections(a:ray)

  if !empty(intersections)
    let intersection = s:nearest_intersection(intersections)
    let t = intersection[0]
    let sphere = intersection[1]

    " point of intersection
    let point = s:vadd(s:scale(t, a:ray[0]), a:ray[1])
    " normal vector
    let normal = s:normalize(s:vsub(point, sphere[0]))

    " shadow check
    let shadow_ray = [
      \ s:normalize(s:vsub(s:light, point)),
      \ s:vadd(point, s:scale(0.01, normal)),
      \ a:ray[2] + 1]
    let shadow_intersections = s:all_intersections(shadow_ray)

    " Lambertian reflection
    let cos_theta = s:dot(normal, s:normalize(s:vsub(s:light, point)))
    if empty(shadow_intersections) && cos_theta > 0.0
      let lambert_color = s:scale(cos_theta, sphere[2])
    else
      let lambert_color = [0.0, 0.0, 0.0]
    endif

    " specular reflection
    let reflection_ray = s:reflect_ray(a:ray, point, normal)
    let specular_color = s:trace(reflection_ray)

    return s:vadd(s:scale(1.0 - sphere[3], lambert_color), s:scale(sphere[3], specular_color))
  endif

  return [0.0, 0.0, 0.0]
endfunction

function! s:trace_pixel(x, y)
  let x = 2.0 * a:x / s:width - 1.0
  let y = 2.0 * (s:height - a:y) / s:height - 1.0
  let ray = [s:normalize([x, y, -2.0]), [0.0, 0.0, 0.0], 1]
  return s:trace(ray)
endfunction

let s:file = [
      \ "P3",
      \ printf("%d %d", s:width, s:height),
      \ "255"]

let percent = 0
for s:y in range(s:height)
  let s:line = []
  for s:x in range(s:width)
    let s:color = s:trace_pixel(s:x, s:y)
    let s:pixel = printf("%d %d %d",
      \ float2nr(255 * s:color[0]),
      \ float2nr(255 * s:color[1]),
      \ float2nr(255 * s:color[2]))
    call add(s:line, s:pixel)
  endfor
  call add(s:file, join(s:line, " "))
  let new_percent = float2nr(100.0 * s:y / s:height)
  if percent != new_percent
    let percent = new_percent
    redrawstatus
    echon printf("\r%3d%%", percent)
  endif
endfor

let s:filename = "image.ppm"
if !filereadable(s:filename) || confirm("image.ppm already exists. overwrite?", "&yes\n&no") == 1
  call writefile(s:file, s:filename, "b")
endif

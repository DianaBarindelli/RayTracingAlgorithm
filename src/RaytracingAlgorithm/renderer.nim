import world
import material
import color
import rayhit
import pcg
from ray import Ray
from exception import NotImplementedError, AbstractMethodError
import std/[options]

type
    Renderer* = ref object of RootObj
        world*: World
        backgroundColor*: Color
        raysShot*: int

    DebugRenderer* = ref object of Renderer

    OnOffRenderer* = ref object of Renderer
        color*: Color

    FlatRenderer* = ref object of Renderer

    PathTracer* = ref object of Renderer
        pcg*: PCG
        numRays*: int
        maxRayDepth*: int
        russianRouletteLimit*: int

        

# ----------- Constructors -----------
func newOnOffRenderer*(world: World, backgroundColor, color: Color): OnOffRenderer {.inline.}=
    return OnOffRenderer(world:world, backgroundColor:backgroundColor, color:color)

func newDebugRenderer*(world: World, backgroundColor: Color): DebugRenderer {.inline.}=
    return DebugRenderer(world:world, backgroundColor: backgroundColor)

func newFlatRenderer*(world: World, backgroundColor: Color): FlatRenderer{.inline.}=
    return FlatRenderer(world: world, backgroundColor: backgroundColor)

func newPathTracer*(world: World, backgroundColor: Color = Color.black(), pcg: PCG = newPCG(), numRays: int = 10, maxRayDepth: int = 2, russianRouletteLimit: int = 3): PathTracer {.inline.}=
    return PathTracer(world: world, backgroundColor: backgroundColor, pcg: pcg, numRays: numRays, maxRayDepth: maxRayDepth, russianRouletteLimit: russianRouletteLimit)

# ------------ Operators --------------
func `$`*(renderer: OnOffRenderer): string =
    return "OnOffRenderer"

func `$`*(renderer: DebugRenderer): string=
    return "DebugRenderer"

func `$`*(renderer: PathTracer): string=
    return "PathTracer"

func `$`*(renderer: FlatRenderer): string=
    return "FlatRenderer"


# ----------- Methods -----------
method Get*(renderer: Renderer): (proc(r: Ray): Color) {.base, raises:[AbstractMethodError].}=
    raise AbstractMethodError.newException("Renderer.Get is an abstract method and cannot be called.")

method Get*(renderer: DebugRenderer): (proc(r: Ray): Color) =
    return proc(r: Ray): Color=
        return renderer.backgroundColor

method Get*(renderer: OnOffRenderer): (proc(r: Ray): Color) =
    return proc(r: Ray): Color=
        let intersection = rayIntersect(renderer.world,r)
        if intersection.isSome:
            return renderer.color
        else:
            return renderer.backgroundColor

method Get*(renderer: FlatRenderer): (proc(r: Ray): Color) =
    return proc(r: Ray): Color =
        var hit: Option[RayHit] = renderer.world.rayIntersect(r)
        if hit == none(RayHit):
            return renderer.backgroundColor

        let material = hit.get().material
        var
            brdfColor: Color = material.brdf.pigment.getColor(hit.get().GetSurfacePoint()) 
            emittedRadianceColor: Color = material.emitted_radiance.getColor(hit.get().GetSurfacePoint())
        return ( brdfColor + emittedRadianceColor )


method Get*(renderer: PathTracer): (proc(ray: Ray): Color) {.gcsafe.} =
    return proc(ray: Ray): Color=
        if ray.depth > renderer.maxRayDepth:
            return Color.black()
        let hitrecord = renderer.world.rayIntersect(ray)
        if hitrecord == none(RayHit):
            return renderer.backgroundColor
        
        let hit = hitrecord.get()
        var hit_color: Color = hit.material.brdf.pigment.getColor(hit.GetSurfacePoint())
        let
            emitted_radiance = hit.material.emitted_radiance.getColor(hit.GetSurfacePoint())
            hit_color_lum = max(hit_color.r, max(hit_color.g, hit_color.b))
        
        if ray.depth >= renderer.russianRouletteLimit:
            let q = max(0.05, 1 - hit_color_lum)
            if renderer.pcg.random_float() > q:
                hit_color = hit_color * (1.0 / (1 - hit_color_lum))
            else:
                return emitted_radiance
        
        var cum_radiance: Color = Color.black()
        if hit_color_lum > 0.0:
            for ray_index in countup(0, renderer.numRays):
                let newRay = hit.material.brdf.ScatterRay(
                    renderer.pcg,
                    hit.ray.dir,
                    hit.world_point,
                    hit.normal,
                    ray.depth + 1
                )
                let newRadiance = renderer.Get()(newRay)
                cum_radiance = cum_radiance + hit_color * newRadiance
                renderer.raysShot  = renderer.raysShot + 1
        return emitted_radiance + cum_radiance * (1.0 / float32(renderer.numRays))

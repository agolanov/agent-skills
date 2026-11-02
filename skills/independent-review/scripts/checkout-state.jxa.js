/* No native architecture has passed the protected Darwin bridge feasibility gate.
 * Never substitute Foundation pathname reads for descriptor-pinned observation.
 * A host with an adequate installed Python uses checkout-state's POSIX engine.
 */
ObjC.import('Foundation');
ObjC.bindFunction('exit', ['void', ['int']]);
function run(argv) {
    var message = 'state verification unavailable: native JXA observation feasibility is unproven on ' +
        ObjC.unwrap($.NSProcessInfo.processInfo.operatingSystemVersionString) +
        '; openat/fstat/fstatat/fdopendir/readdir/readlinkat/read/close/proc_pidinfo, ' +
        'architecture-specific INODE64 exports/layouts, lossless identity JSON and ' +
        'streaming CommonCrypto vectors require actual-host proof. macOS without Python remains incomplete.\n';
    $.NSFileHandle.fileHandleWithStandardError.writeData($(message).dataUsingEncoding($.NSUTF8StringEncoding));
    $.exit(2);
}

function setup_eidors(eidorsStartupPath, netgenDirPath)
    % setupEidors initializes EIDORS with the provided startup path.
    % If running on macOS, it also configures the Netgen path.
    %
    % Parameters:
    %   eidorsStartupPath (string): The path to the EIDORS startup.m file.
    %   netgenDirPath (string): The deirectory path to Netgen, required for macOS.

    % Run the EIDORS startup script
    run(eidorsStartupPath);
    
    if ismac
        setenv('NETGENDIR', netgenDirPath);
        setenv('PATH', [netgenDirPath, ':', getenv('PATH')]);
    end
    eidors_cache('cache_size', 10*1024*1024*1024); 
end

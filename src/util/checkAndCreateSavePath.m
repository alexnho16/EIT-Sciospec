function savePath = checkAndCreateSavePath(savePath)
    if ~exist(savePath, 'dir')
        mkdir(savePath);
        fprintf('Directory created: %s\n', savePath);
    else
        fprintf('Directory already exists: %s\n', savePath);
    end
end
